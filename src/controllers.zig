const std = @import("std");
const httpz = @import("httpz");
const core = @import("core.zig");
const class = @import("class.zig");
const utils = @import("utils.zig");
const assets = @import("assets.zig");


pub fn watch_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;
    const app = handler.app;
    const ctx = class.WatchContext {
        .hub = app.hub,
        .gpa = app.gpa,
        .io = app.io
    };
    if (try httpz.upgradeWebsocket(class.WatchClient, request, response, &ctx) == false) {
        bad_request_handler(response, "[HTTP 400] invalid websocket upgrade");
    }
}


pub fn login_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    const app = handler.app;
    if (request.method == .GET) {
        const ui = utils.find_asset("UI/login.html") orelse {
            response.status = 500;
            response.body = "[HTTP 500] fail to load \"login.html\" webpage";
            return;
        };
        return serve_assets_handler(request, response, ui);
    }
    if (request.method != .POST) {
        response.status = 405;
        response.body = "[HTTP 405] only POST request is allowed";
        return;
    }
    const form = try request.formData();
    const password = form.get("password") orelse "";
    if (std.mem.eql(u8, password, app.cfg.login_pwd)) {
        var random: [32]u8 = undefined;
        try app.io.randomSecure(&random);
        const session = std.fmt.bytesToHex(random, .lower);
        try core.mark_authenticated(app.state, app.io, app.gpa, &session);
        response.status = 303;
        response.header("Location", "/");
        response.header(
            "Set-Cookie",
            try std.fmt.allocPrint(
                response.arena,
                "ziger_session={s}; Path=/; HttpOnly; SameSite=Strict; Max-Age=1800",
                .{ session }
            )
        );
        response.header("Cache-Control", "no-store");
        return;
    }
    response.status = 401;
    response.body = "[HTTP 401] wrong password";
}


pub fn index_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;
    if (!std.mem.eql(u8, request.url.path, "/")) {
        response.status = 404;
        response.body = "[HTTP 404] not found";
        return;
    }
    const ui = utils.find_asset("UI/index.html") orelse {
        response.status = 500;
        response.body = "[HTTP 500] fail to load \"index.html\" webpage";
        return;
    };
    response.content_type = .HTML;
    response.header("Cache-Control", "private, no-cache");
    response.body = try core.render_index(response.arena, ui.file, handler.app.state);
}


pub fn ui_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;
    const ui = utils.find_asset(request.url.path[1..]) orelse {
        response.status = 404;
        response.body = "[HTTP 404] file not found";
        return;
    };
    return serve_assets_handler(request, response, ui);
}


pub fn docs_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;
    const ui = utils.find_asset("UI/docs.html") orelse {
        response.status = 500;
        response.body = "[HTTP 500] fail to load \"docs.html\" webpage";
        return;
    };
    return serve_assets_handler(request, response, ui);
}


pub fn filelist_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;
    const app = handler.app;
    const q = try request.query();
    const path = q.get("path") orelse ".";
    if (!utils.access_super(path) or !utils.confined_path(app.io, app.cfg.share_dir, path, false)) {
        bad_request_handler(response, "[HTTP 400] forbid accessing parent");
        return;
    }
    const list = try core.list_dir(app.io, response.arena, app.cfg.share_dir, path);
    response.header("Access-Control-Allow-Origin", "*");
    try response.json(list, .{});
}


pub fn share_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;
    const app = handler.app;
    const prefix = "/api/share/";
    if (!std.mem.startsWith(u8, request.url.path, prefix)) {
        response.status = 404;
        return;
    }
    const path = try decode_url_path_handler(request.url.path[prefix.len..], response) orelse return;
    if (!utils.access_item(path)) {
        bad_request_handler(response, "[HTTP 400] forbid accessing parent");
        return;
    }
    var parent = utils.open_confined_parent(app.io, app.cfg.share_dir, path) catch {
        bad_request_handler(response, "[HTTP 400] forbid accessing parent");
        return;
    };
    defer parent.close(app.io);
    const file = parent.dir.openFile(app.io, parent.leaf, .{ .follow_symlinks = false, .resolve_beneath = true }) catch {
        response.status = 404;
        response.body = "[HTTP 404] file not found";
        return;
    };
    defer file.close(app.io);

    const stat = try file.stat(app.io);
    if (stat.kind == .directory) {
        const list = core.list_dir(app.io, response.arena, app.cfg.share_dir, path) catch &[_]class.FileInfo{};
        response.content_type = .HTML;
        const w = response.writer();
        try w.writeAll("<pre>\n");
        for (list) |item| try w.print("<a href=\"{s}\">{s}</a>\n", .{ item.FileName, item.FileName });
        try w.writeAll("</pre>");
        return;
    }

    var reader_buffer: [64 * 1024]u8 = undefined;
    var fr = file.reader(app.io, &reader_buffer);
    var first_chunk: [64 * 1024]u8 = undefined;
    const first_chunk_len = try fr.interface.readSliceShort(&first_chunk);

    const presentation = core.content_presentation(
        path,
        first_chunk[0 .. first_chunk_len],
        first_chunk_len < first_chunk.len
    );

    const disposition = if (presentation.should_inline) "inline" else "attachment";
    response.header("Content-Type", presentation.content_type);
    response.header("Content-Disposition", try std.fmt.allocPrint(response.arena, "{s}; filename=\"{s}\"", .{ disposition, std.fs.path.basename(path) }));

    if (first_chunk_len > 0) try response.chunk(first_chunk[0..first_chunk_len]);
    var dst: [256 * 1024]u8 = undefined;
    while (true) {
        const n = try fr.interface.readSliceShort(&dst);
        if (n == 0) break;
        try response.chunk(dst[0 .. n]);
        if (n < dst.len) break;
    }
}


pub fn file_property_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;
    const app = handler.app;
    const items = try request_json_handler([]const class.FileRequest, request, response) orelse return;
    const property = try core.calculate_property(app.io, response.arena, app.cfg.share_dir, items);
    response.header("Access-Control-Allow-Origin", "*");
    try response.json(property, .{});
}


pub fn edit_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_announcement)) return;
    const app = handler.app;

    const max_body_size = @as(usize, @intCast(@max(app.cfg.max_bytes(), 1024 * 1024)));
    if (request.body_len > max_body_size) {
        response.status = 413;
        response.body = "[HTTP 413] request body is too large";
        return;
    }

    const body = core.read_full_request_body(request, 60 * 1000) catch {
        bad_request_handler(response, "[HTTP 400] invalid request body");
        return;
    };
    const upd = parse_json_handler(
        struct { Content: []const u8 = "" },
        request.arena,
        body,
        response
    ) orelse return;

    app.state.mutex.lockUncancelable(app.io);
    defer app.state.mutex.unlock(app.io);
    app.state.content_editable.clearRetainingCapacity();
    try app.state.content_editable.appendSlice(app.gpa, upd.Content);
}


pub fn announcement_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_announcement)) return;
    const app = handler.app;
    app.state.mutex.lockUncancelable(app.io);
    defer app.state.mutex.unlock(app.io);
    const snapshot = try response.arena.dupe(u8, app.state.content_editable.items);
    response.header("Access-Control-Allow-Origin", "*");
    try response.json(.{ .Content = snapshot }, .{});
}


pub fn upload_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_upload)) return;
    const app = handler.app;
    const content_type = request.header("content-type") orelse {
        bad_request_handler(response, "[HTTP 400] missing content-type");
        return;
    };
    if (request.body_len > utils.upload_request_limit(app.cfg)) {
        response.status = 413;
        response.body = "[HTTP 413] request body is too large";
        return;
    }
    var rr = request.reader(60 * 1000) catch {
        response.status = 500;
        response.body = "[HTTP 500] fail to acquire body reader";
        return;
    };
    const cr = class.ChunkReader{ .ctx = @ptrCast(&rr), .callback = http_reader_handler };
    app.state.file_mutex.lockUncancelable(app.io);
    defer app.state.file_mutex.unlock(app.io);
    const results = core.streaming_multipart(app.io, app.gpa, app.cfg, content_type, cr) catch |err| {
        response.status = if (err == error.UnsafePath) 400 else if (err == error.FileTooLarge) 413 else 500;
        response.body = if (err == error.UnsafePath) "[HTTP 400] invalid or unsafe upload path" else if (err == error.FileTooLarge) "[HTTP 413] uploaded file is too large" else "[HTTP 500] fail to parse form";
        return;
    };
    defer {
        for (results) |result| app.gpa.free(result.Path);
        app.gpa.free(results);
    }
    try operation_results_handler(response, results);
}


pub fn search_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_search)) return;
    const app = handler.app;
    const items = try request_json_handler(class.FileSearch, request, response) orelse return;
    const results = try core.search_file(app.io, response.arena, app.cfg.share_dir, items);
    response.header("Access-Control-Allow-Origin", "*");
    try response.json(results, .{});
}


pub fn delete_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_delete)) return;
    const app = handler.app;
    const items = try request_json_handler([]const class.FileRequest, request, response) orelse return;
    app.state.file_mutex.lockUncancelable(app.io);
    defer app.state.file_mutex.unlock(app.io);
    const results = try core.delete_file(app.io, response.arena, app.cfg.share_dir, items);
    try operation_results_handler(response, results);
}


pub fn batch_download_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try is_authenticated_handler(handler, request, response)) return;

    const app = handler.app;
    const items = try request_json_handler([]const class.FileRequest, request, response) orelse return;
    app.state.file_mutex.lockUncancelable(app.io);
    defer app.state.file_mutex.unlock(app.io);

    var random: [16]u8 = undefined;
    app.io.random(&random);
    const token = std.fmt.bytesToHex(random, .lower);
    const tmp_name = try std.fmt.allocPrint(response.arena, ".download.{s}.zip", .{ token });
    const tmp_path = try utils.join_path(response.arena, app.cfg.store_dir, &.{ tmp_name });
    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(app.io, app.cfg.store_dir) catch {
        response.status = 500;
        response.body = "[HTTP 500] archive storage is unavailable";
        return;
    };
    const archive_file = cwd.createFile(app.io, tmp_path, .{ .exclusive = true }) catch {
        response.status = 500;
        response.body = "[HTTP 500] fail to create temporary archive";
        return;
    };
    defer cwd.deleteFile(app.io, tmp_path) catch {};
    {
        defer archive_file.close(app.io);
        var write_buffer: [64 * 1024]u8 = undefined;
        var fw = archive_file.writer(app.io, &write_buffer);
        core.write_batch_archive(app.io, response.arena, app.cfg.share_dir, items, &fw.interface) catch |err| {
            response.status = switch (err) {
                error.EmptySelection, error.UnsafePath, error.DuplicateArchiveName, error.SymbolicLinkNotAllowed, error.UnsupportedFileType, error.FileNotFound => 400,
                else => 500
            };
            response.body = try std.fmt.allocPrint(response.arena, "[HTTP {d}] batch download failed: {s}", .{ response.status, @errorName(err) });
            return;
        };
    }

    const file = cwd.openFile(app.io, tmp_path, .{}) catch {
        response.status = 500;
        response.body = "[HTTP 500] fail to open temporary archive";
        return;
    };
    defer file.close(app.io);
    const stat = try file.stat(app.io);
    response.header("Content-Type", "application/zip");
    response.header("Content-Disposition", "attachment; filename=\"archive.zip\"");
    response.header("Content-Length", try std.fmt.allocPrint(response.arena, "{d}", .{ stat.size }));
    response.header("Access-Control-Allow-Origin", "*");

    var reader_buffer: [64 * 1024]u8 = undefined;
    var fr = file.reader(app.io, &reader_buffer);
    var chunk: [256 * 1024]u8 = undefined;
    while (true) {
        const n = try fr.interface.readSliceShort(&chunk);
        if (n == 0) break;
        try response.chunk(chunk[0 .. n]);
        if (n < chunk.len) break;
    }
}


pub fn makedir_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_mkdir)) return;
    const app = handler.app;
    const items = try request_json_handler(class.FileRequest, request, response) orelse return;
    app.state.file_mutex.lockUncancelable(app.io);
    defer app.state.file_mutex.unlock(app.io);
    const result = try core.make_dir(app.io, response.arena, app.cfg.share_dir, items);
    if (!result.Success) response.status = if (std.mem.startsWith(u8, result.Error, "invalid")) 400 else if (std.mem.eql(u8, result.Error, "destination exists")) 409 else 500;
    try response.json(&[_]class.FileOperationResult{ result }, .{});
}


pub fn copy_file_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_copy)) return;
    const app = handler.app;
    const items = try request_json_handler([]const class.FileRequest, request, response) orelse return;
    app.state.file_mutex.lockUncancelable(app.io);
    defer app.state.file_mutex.unlock(app.io);
    const results = try core.copy_file(app.io, response.arena, app.cfg.share_dir, items);
    try operation_results_handler(response, results);
}


pub fn move_file_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_move)) return;
    const app = handler.app;
    const items = try request_json_handler([]const class.FileRequest, request, response) orelse return;
    app.state.file_mutex.lockUncancelable(app.io);
    defer app.state.file_mutex.unlock(app.io);
    const results = try core.move_file(app.io, response.arena, app.cfg.share_dir, items);
    try operation_results_handler(response, results);
}


pub fn rename_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !void {
    if (!try require_option_handler(handler, request, response, .status_rename)) return;
    const app = handler.app;
    const items = try request_json_handler([]const class.FileRename, request, response) orelse return;
    app.state.file_mutex.lockUncancelable(app.io);
    defer app.state.file_mutex.unlock(app.io);
    const results = try core.rename_file(app.io, response.arena, app.cfg.share_dir, items);
    try operation_results_handler(response, results);
}


fn operation_results_handler(response: *httpz.Response, results: []const class.FileOperationResult) !void {
    if (results.len == 0) {
        response.status = 400;
        return response.json(results, .{});
    }
    var succeeded: usize = 0;
    var invalid: usize = 0;
    for (results) |result| if (result.Success) {
        succeeded = succeeded + 1;
    } else if (std.mem.startsWith(u8, result.Error, "invalid")) {
        invalid = invalid + 1;
    };
    if (succeeded != results.len) response.status = if (succeeded > 0) 207 else if (invalid == results.len) 400 else 409;
    try response.json(results, .{});
}


fn bad_request_handler(response: *httpz.Response, msg: []const u8) void {
    response.status = 400;
    response.body = msg;
}


fn decode_url_path_handler(encoded: []const u8, response: *httpz.Response) !?[]const u8 {
    const decoded = try response.arena.alloc(u8, encoded.len);
    var source: usize = 0;
    var destination: usize = 0;
    while (source < encoded.len) {
        if (encoded[source] != '%') {
            decoded[destination] = encoded[source];
            source = source + 1;
            destination = destination + 1;
            continue;
        }
        if (source + 2 >= encoded.len) {
            bad_request_handler(response, "[HTTP 400] invalid URL encoding");
            return null;
        }
        const high = std.fmt.charToDigit(encoded[source + 1], 16) catch {
            bad_request_handler(response, "[HTTP 400] invalid URL encoding");
            return null;
        };
        const low = std.fmt.charToDigit(encoded[source + 2], 16) catch {
            bad_request_handler(response, "[HTTP 400] invalid URL encoding");
            return null;
        };
        decoded[destination] = high << 4 | low;
        source = source + 3;
        destination = destination + 1;
    }
    const path = decoded[0..destination];
    if (!std.unicode.utf8ValidateSlice(path)) {
        bad_request_handler(response, "[HTTP 400] URL path is not valid UTF-8");
        return null;
    }
    return path;
}


fn redirect_login_handler(response: *httpz.Response) void {
    response.status = 302;
    response.body = "";
    response.header("Location", "/login/");
    response.header("Cache-Control", "no-store");
}


fn http_reader_handler(ctx: *anyopaque, dst: []u8) anyerror!usize {
    const r: *httpz.Request.Reader = @ptrCast(@alignCast(ctx));
    return r.read(dst);
}


fn request_json_handler(comptime T: type, request: *httpz.Request, response: *httpz.Response) !?T {
    return try request.json(T) orelse {
        bad_request_handler(response, "[HTTP 400] invalid request body");
        return null;
    };
}


fn parse_json_handler(comptime T: type, allocator: std.mem.Allocator, body: ?[]const u8, response: *httpz.Response) ?T {
    return (
        if (body) |b| std.json.parseFromSliceLeaky(T, allocator, b, .{}) catch null
        else null
    ) orelse {
        bad_request_handler(response, "[HTTP 400] invalid request body");
        return null;
    };
}


fn is_authenticated_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response) !bool {
    const app = handler.app;
    const user = try user_of_handler(handler, request);
    defer app.gpa.free(user);
    if (core.is_locked(app.state, app.io, app.gpa, app.cfg, user)) {
        redirect_login_handler(response);
        return false;
    }
    return true;
}


fn require_option_handler(handler: *class.Handler, request: *httpz.Request, response: *httpz.Response, option: class.WebOption) !bool {
    if (!try is_authenticated_handler(handler, request, response)) return false;
    if (!handler.app.state.enable_status_for(option)) {
        response.status = 403;
        response.body = "[HTTP 403]: forbidden";
        return false;
    }
    return true;
}


fn user_of_handler(handler: *class.Handler, request: *httpz.Request) ![]u8 {
    const app = handler.app;
    const cookie = request.header("cookie") orelse return app.gpa.dupe(u8, "");
    var fields = std.mem.splitScalar(u8, cookie, ';');
    while (fields.next()) |field_raw| {
        const field = std.mem.trim(u8, field_raw, " \t");
        const prefix = "ziger_session=";
        if (std.mem.startsWith(u8, field, prefix)) return app.gpa.dupe(u8, field[prefix.len..]);
    }
    return app.gpa.dupe(u8, "");
}


fn serve_assets_handler(request: *httpz.Request, response: *httpz.Response, ui: class.UI) !void {
    const etag = try std.fmt.allocPrint(request.arena, "\"{s}\"", .{ ui.etag });
    if (request.header("if-none-match")) |inm| {
        if (std.mem.indexOf(u8, inm, etag) != null) {
            response.status = 304;
            response.header("ETag", etag);
            response.header("Cache-Control", "no-cache");
            return;
        }
    }
    response.header("ETag", etag);
    response.header("Cache-Control", "no-cache");
    response.header("Content-Type", utils.multipurpose_internet_mail_extensions(ui.path));
    response.body = ui.file;
}