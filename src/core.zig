const std = @import("std");
const httpz = @import("httpz");
const usage = @import("usage.zig");
const utils = @import("utils.zig");
const class = @import("class.zig");
const assets = @import("assets.zig");


pub fn cleanup_transfer_temporary_files(io: std.Io, store_dir: []const u8) void {
    var dir = std.Io.Dir.cwd().openDir(io, store_dir, .{ .iterate = true }) catch return;
    defer dir.close(io);

    var iterator = dir.iterate();
    while (iterator.next(io) catch null) |entry| {
        if (utils.is_internal_temporary_name(entry.name)) dir.deleteTree(io, entry.name) catch {};
    }
}


pub fn read_full_request_body(request: *httpz.Request, timeout_ms: usize) !?[]const u8 {
    if (request.body_buffer == null) return null;
    const body = try request.arena.alloc(u8, request.body_len);
    var reader = try request.reader(timeout_ms);
    var pos: usize = 0;
    while (pos < body.len) {
        const n = try reader.read(body[pos .. ]);
        if (n == 0) return error.EndOfStream;
        pos = pos + n;
    }
    return body;
}


pub fn is_locked(
    state: *class.AppState,
    io: std.Io,
    allocator: std.mem.Allocator,
    cfg: *const class.AppConfig,
    user: []const u8
) bool {
    if (cfg.login_pwd.len == 0) return false;
    if (user.len == 0) return true;
    state.mutex.lockUncancelable(io);
    defer state.mutex.unlock(io);
    const now = std.Io.Clock.real.now(io).toSeconds();
    if (state.user_lock.get(user)) |deadline| {
        if (now < deadline) return false;
        if (state.user_lock.fetchRemove(user)) |entry| allocator.free(entry.key);
    }
    return true;
}


pub fn content_presentation(path: []const u8, sample: []const u8, sample_reached_eof: bool) class.ContentPresentation {
    const extension_mime = utils.multipurpose_internet_mail_extensions(path);
    const extension_says_text = utils.is_textual_mime(extension_mime);
    const unknown_type = std.mem.eql(u8, extension_mime, "application/octet-stream");
    const content_says_text = (extension_says_text or unknown_type) and utils.is_probably_plain_text(sample, sample_reached_eof);

    if (content_says_text) return .{ .content_type = if (extension_says_text) extension_mime else "text/plain; charset=utf-8", .should_inline = true };
    if (extension_says_text) return .{ .content_type = "application/octet-stream", .should_inline = false };
    return .{ .content_type = extension_mime, .should_inline = utils.is_viewable_mime(extension_mime) };
}


pub fn mark_authenticated(state: *class.AppState, io: std.Io, allocator: std.mem.Allocator, user: []const u8) !void {
    state.mutex.lockUncancelable(io);
    defer state.mutex.unlock(io);
    const deadline = std.Io.Clock.real.now(io).toSeconds() + 30 * 60;
    while (true) {
        var expired: ?[]const u8 = null;
        var iterator = state.user_lock.iterator();
        while (iterator.next()) |entry| if (entry.value_ptr.* <= deadline - 30 * 60) {
            expired = entry.key_ptr.*;
            break;
        };
        const key = expired orelse break;
        if (state.user_lock.fetchRemove(key)) |entry| allocator.free(entry.key);
    }
    const gop = try state.user_lock.getOrPut(allocator, user);
    if (!gop.found_existing) gop.key_ptr.* = try allocator.dupe(u8, user);
    gop.value_ptr.* = deadline;
}


pub fn render_index(allocator: std.mem.Allocator, src: []const u8, state: *class.AppState) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < src.len) {
        const open = std.mem.indexOfPos(u8, src, i, "{{") orelse {
            try out.appendSlice(allocator, src[i .. ]);
            break;
        };
        try out.appendSlice(allocator, src[i .. open]);

        const close = std.mem.indexOfPos(u8, src, open + 2, "}}") orelse {
            try out.appendSlice(allocator, src[open .. ]);
            break;
        };
        const directive = std.mem.trim(u8, src[open + 2 .. close], " \t");

        if (std.mem.startsWith(u8, directive, "if ")) {
            const expression = std.mem.trim(u8, directive[3 .. ], " \t.");
            const condition = utils.lookup_web_option(state, expression) orelse false;
            const end_open = std.mem.indexOfPos(u8, src, close + 2, "{{") orelse break;
            const end_close = std.mem.indexOfPos(u8, src, end_open + 2, "}}") orelse break;
            if (condition) try out.appendSlice(allocator, src[close + 2 .. end_open]);
            i = end_close + 2;
            continue;
        }

        try out.appendSlice(allocator, src[open .. close + 2]);
        i = close + 2;
    }
    return out.toOwnedSlice(allocator);
}


pub fn list_dir(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, path: []const u8) ![]class.FileInfo {
    var list: std.ArrayList(class.FileInfo) = .empty;
    errdefer list.deinit(allocator);

    if (!std.mem.eql(u8, path, ".") and path.len != 0) {
        try list.append(allocator, .{ .FileName = try allocator.dupe(u8, ". ."), .FileSize = try allocator.dupe(u8, ""), .FileIcon = try allocator.dupe(u8, "NULL"), .ModifiedTime = try allocator.dupe(u8, "") });
    }

    var dir = utils.open_confined_dir(io, share_dir, path, true) catch return list.toOwnedSlice(allocator);
    defer dir.close(io);

    var iterator = dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (utils.is_internal_temporary_name(entry.name)) continue;
        if (entry.kind == .sym_link) continue;
        const is_directory = entry.kind == .directory;
        if (is_directory) {
            try list.append(allocator, .{ .FileName = try allocator.dupe(u8, entry.name), .FileSize = try allocator.dupe(u8, "----"), .FileIcon = try allocator.dupe(u8, "FOLDER"), .ModifiedTime = try allocator.dupe(u8, "") });
            continue;
        }
        const stat = dir.statFile(io, entry.name, .{}) catch continue;
        const icon = blk: {
            const extension = std.fs.path.extension(entry.name);
            if (extension.len <= 1) break :blk try allocator.dupe(u8, "NULL");
            const lower = try allocator.alloc(u8, extension.len - 1);
            for (extension[1 .. ], 0 .. ) |c, i| lower[i] = std.ascii.toLower(c);
            break :blk lower;
        };
        try list.append(allocator, .{ .FileName = try allocator.dupe(u8, entry.name), .FileSize = try utils.format_file_size(allocator, @intCast(stat.size)), .FileIcon = icon, .ModifiedTime = try utils.format_time(allocator, stat.mtime) });
    }
    return list.toOwnedSlice(allocator);
}


pub fn calculate_property(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, items: []const class.FileRequest) !class.FileProperty {
    var file_count: i64 = 0;
    var sum_size: i64 = 0;
    var latest_mtime: std.Io.Timestamp = .zero;
    var saw_anything = false;

    for (items) |item| {
        var parent = utils.open_confined_parent(io, share_dir, item.Path) catch continue;
        defer parent.close(io);
        const stat = parent.dir.statFile(io, parent.leaf, .{ .follow_symlinks = false }) catch continue;
        if (stat.kind == .sym_link) continue;
        saw_anything = true;

        if (stat.kind == .directory) {
            var dir = parent.dir.openDir(io, parent.leaf, .{ .iterate = true, .follow_symlinks = false }) catch continue;
            defer dir.close(io);
            const r: class.FileSizeCount = utils.folder_size_count(io, allocator, dir) catch class.FileSizeCount{ .size = 0, .count = 0 };
            sum_size = sum_size + r.size;
            file_count = file_count + r.count;
        }
        else {
            sum_size = sum_size + @as(@TypeOf(sum_size), @intCast(stat.size));
            file_count = file_count + 1;
        }
        if (stat.mtime.nanoseconds > latest_mtime.nanoseconds) latest_mtime = stat.mtime;
    }

    if (!saw_anything) {
        return .{ .FileCount = 0, .SumSize = try allocator.dupe(u8, "NULL"), .ModifiedTime = try allocator.dupe(u8, "NULL"), .AgoTime = try allocator.dupe(u8, "NULL") };
    }
    if (items.len == 1 and file_count == 0) file_count = 1;

    return .{ .FileCount = file_count, .SumSize = try utils.format_file_size(allocator, sum_size), .ModifiedTime = try utils.format_time(allocator, latest_mtime), .AgoTime = try utils.ago_time(io, allocator, latest_mtime) };
}


pub fn streaming_multipart(
    io: std.Io,
    gpa: std.mem.Allocator,
    cfg: *const class.AppConfig,
    content_type: []const u8,
    reader: class.ChunkReader
) ![]class.FileOperationResult {
    var results: std.ArrayList(class.FileOperationResult) = .empty;
    errdefer {
        for (results.items) |result| gpa.free(result.Path);
        results.deinit(gpa);
    }
    const bm = "boundary=";
    const idx = std.mem.indexOf(u8, content_type, bm) orelse return error.NoBoundary;
    var boundary_raw = content_type[idx + bm.len .. ];
    if (std.mem.indexOfAny(u8, boundary_raw, ";")) |sc| boundary_raw = boundary_raw[0 .. sc];
    boundary_raw = std.mem.trim(u8, boundary_raw, " \t\"");

    const sep_first = try std.fmt.allocPrint(gpa, "--{s}", .{boundary_raw});
    defer gpa.free(sep_first);
    const sep = try std.fmt.allocPrint(gpa, "\r\n--{s}", .{boundary_raw});
    defer gpa.free(sep);
    const buffer = try gpa.alloc(u8, 128 * 1024);
    defer gpa.free(buffer);

    var sp: class.SlidingWindowMultipartStreamParser = .{ .buffer = buffer, .reader = reader };
    try sp.skip_until_boundary(sep_first);

    var current_dir_owned: []u8 = "";
    defer if (current_dir_owned.len > 0) gpa.free(current_dir_owned);
    var current_dir: []const u8 = ".";
    const upload_uses_share = std.mem.eql(u8, cfg.store_dir, cfg.share_dir);
    var pending_rel: ?[]u8 = null;
    defer if (pending_rel) |rel| gpa.free(rel);
    var pending_tmp: ?[]u8 = null;
    defer if (pending_tmp) |tmp| {
        std.Io.Dir.cwd().deleteFile(io, tmp) catch {};
        gpa.free(tmp);
    };
    var active_tmp: ?[]u8 = null;
    defer if (active_tmp) |tmp| {
        std.Io.Dir.cwd().deleteFile(io, tmp) catch {};
        gpa.free(tmp);
    };

    const cwd = std.Io.Dir.cwd();
    const session_ns = std.Io.Clock.real.now(io).toNanoseconds();
    const session_tid: u64 = @intCast(std.Thread.getCurrentId());
    var tmp_seq: usize = 0;

    parts_loop: while (true) {
        const peek2 = sp.fill_at_least(2) catch break :parts_loop;
        if (peek2.len < 2) break;
        if (peek2[0] == '-' and peek2[1] == '-') break;
        if (peek2[0] != '\r' or peek2[1] != '\n') break;

        sp.advance(2);

        var hdr_buffer: [4096]u8 = undefined;
        const hdr_slice = try sp.collect_until_needle("\r\n\r\n", &hdr_buffer);

        var part_name: []const u8 = "";
        var part_filename: ?[]const u8 = null;
        var lit = std.mem.splitSequence(u8, hdr_slice, "\r\n");

        while (lit.next()) |line| {
            if (!std.ascii.startsWithIgnoreCase(line, "content-disposition:")) continue;
            if (std.mem.indexOf(u8, line, "name=\"")) |p| {
                const start = p + "name=\"".len;
                if (std.mem.indexOfScalarPos(u8, line, start, '"')) |q| part_name = line[start .. q];
            }
            if (std.mem.indexOf(u8, line, "filename=\"")) |p| {
                const start = p + "filename=\"".len;
                if (std.mem.indexOfScalarPos(u8, line, start, '"')) |q| part_filename = line[start .. q];
            }
        }

        if (std.mem.eql(u8, part_name, "File") and part_filename != null) {
            const tmp_name = try std.fmt.allocPrint(gpa, ".upload.{d}.{d}.{d}.tmp", .{ session_tid, session_ns, tmp_seq });
            tmp_seq = tmp_seq + 1;
            const tmp_path = try utils.join_path(gpa, cfg.store_dir, &.{tmp_name});
            gpa.free(tmp_name);
            active_tmp = tmp_path;

            if (std.fs.path.dirname(tmp_path)) |dd| cwd.createDirPath(io, dd) catch {};
            const file = cwd.createFile(io, tmp_path, .{ .exclusive = true }) catch {
                try sp.skip_until_boundary(sep);
                if (pending_rel) |rel| {
                    try append_upload_result(gpa, &results, rel, false, "temporary file creation failed");
                    gpa.free(rel);
                    pending_rel = null;
                }
                gpa.free(tmp_path);
                active_tmp = null;
                continue :parts_loop;
            };

            {
                defer file.close(io);
                var write_buffer: [64 * 1024]u8 = undefined;
                var fw = file.writer(io, &write_buffer);
                try sp.stream_until_boundary(&fw.interface, sep, @intCast(@max(cfg.max_bytes(), 0)));
                try fw.interface.flush();
            }

            if (pending_rel) |rel| {
                const renamed = finish_uploaded_tmp(io, gpa, cfg, current_dir, rel, tmp_path) catch false;
                try append_upload_result(gpa, &results, rel, renamed, if (renamed) "" else "destination exists or upload failed");
                gpa.free(rel);
                pending_rel = null;
                if (renamed) {
                    gpa.free(tmp_path);
                    active_tmp = null;
                }
                else {
                    cwd.deleteFile(io, tmp_path) catch {};
                    gpa.free(tmp_path);
                    active_tmp = null;
                }
            }
            else {
                if (pending_tmp) |old_tmp| {
                    cwd.deleteFile(io, old_tmp) catch {};
                    gpa.free(old_tmp);
                }
                pending_tmp = tmp_path;
                active_tmp = null;
            }
        }
        else if (std.mem.eql(u8, part_name, "RelativePath")) {
            var val_buffer: [4096]u8 = undefined;
            const rel = try sp.collect_until_boundary(sep, &val_buffer);
            if (!utils.access_super(rel)) {
                try append_upload_result(gpa, &results, rel, false, "invalid or unsafe path");
                if (pending_tmp) |tmp| {
                    cwd.deleteFile(io, tmp) catch {};
                    gpa.free(tmp);
                    pending_tmp = null;
                }
                continue :parts_loop;
            }
            if (pending_tmp) |tmp| {
                const renamed = finish_uploaded_tmp(io, gpa, cfg, current_dir, rel, tmp) catch false;
                pending_tmp = null;
                if (renamed) {
                    gpa.free(tmp);
                }
                else {
                    cwd.deleteFile(io, tmp) catch {};
                    gpa.free(tmp);
                }
                try append_upload_result(gpa, &results, rel, renamed, if (renamed) "" else "destination exists or upload failed");
            }
            else {
                if (pending_rel) |old_rel| gpa.free(old_rel);
                pending_rel = try gpa.dupe(u8, rel);
            }
        }
        else if (std.mem.eql(u8, part_name, "CurrentDir")) {
            var val_buffer: [4096]u8 = undefined;
            const slice = try sp.collect_until_boundary(sep, &val_buffer);
            if (upload_uses_share and current_dir_owned.len == 0) {
                if (!utils.access_super(slice)) return error.UnsafePath;
                current_dir_owned = try gpa.dupe(u8, slice);
                current_dir = current_dir_owned;
            }
        } else try sp.skip_until_boundary(sep);
    }
    if (pending_rel) |rel| try append_upload_result(gpa, &results, rel, false, "missing file data");
    if (pending_tmp != null) try append_upload_result(gpa, &results, "", false, "missing relative path");
    return results.toOwnedSlice(gpa);
}


fn append_upload_result(
    allocator: std.mem.Allocator,
    results: *std.ArrayList(class.FileOperationResult),
    path: []const u8,
    success: bool,
    message: []const u8
) !void {
    try results.append(allocator, .{ .Path = try allocator.dupe(u8, path), .Success = success, .Error = message });
}


pub fn search_file(
    io: std.Io,
    allocator: std.mem.Allocator,
    scratch_allocator: std.mem.Allocator,
    share_dir: []const u8,
    request: class.FileSearch
) !class.SearchResponse {
    var out: std.ArrayList(class.SearchResult) = .empty;
    errdefer {
        for (out.items) |h| {
            allocator.free(h.Path);
            if (h.Description.len > 0) allocator.free(h.Description);
        }
        out.deinit(allocator);
    }

    const page_size = @min(if (request.Limit == 0) class.search_default_page_size else request.Limit, class.search_max_results);
    var budget: class.SearchBudget = .{ .started = std.Io.Clock.awake.now(io) };
    var matched: usize = 0;
    var has_more = false;

    if (request.Target.len == 0 or request.Path.len == 0) return search_response(allocator, &out, request.Offset, has_more, budget);
    if (!utils.access_super(request.CurrentDir) or !utils.confined_path(io, share_dir, request.CurrentDir, false)) return search_response(allocator, &out, request.Offset, has_more, budget);

    for (request.Path, 0 .. ) |root, root_index| {
        if (root_index >= class.search_max_roots or budget.exhausted(io)) {
            budget.truncated = true;
            break;
        }
        if (search_root_seen(request.Path[0 .. root_index], root)) continue;
        if (!utils.access_item(root)) continue;
        const display_root = utils.relative_search_path(request.CurrentDir, root) orelse continue;
        var dir = utils.open_confined_dir(io, share_dir, root, true) catch {
            var parent = utils.open_confined_parent(io, share_dir, root) catch continue;
            defer parent.close(io);
            const stat = parent.dir.statFile(io, parent.leaf, .{ .follow_symlinks = false }) catch continue;
            if (stat.kind == .sym_link or stat.kind == .directory) continue;
            budget.scanned_files = budget.scanned_files + 1;
            if (try append_search_page_result(io, allocator, scratch_allocator, &out, parent.dir, parent.leaf, std.fs.path.basename(root), display_root, request.Target, true, request.Offset, page_size, &matched)) has_more = true;
            if (has_more) break;
            continue;
        };
        defer dir.close(io);
        if (try append_search_page_result(io, allocator, scratch_allocator, &out, dir, "", std.fs.path.basename(root), display_root, request.Target, false, request.Offset, page_size, &matched)) {
            has_more = true;
            break;
        }

        var walker = try dir.walk(scratch_allocator);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (budget.exhausted(io)) break;
            if (entry.depth() > class.search_max_depth) {
                if (entry.kind == .directory) walker.leave(io);
                continue;
            }
            if (entry.kind == .sym_link) continue;
            budget.scanned_files = budget.scanned_files + 1;
            const rel = try std.fs.path.join(scratch_allocator, &.{ root, entry.path });
            defer scratch_allocator.free(rel);
            const display_path = utils.relative_search_path(request.CurrentDir, rel) orelse continue;
            if (try append_search_page_result(io, allocator, scratch_allocator, &out, entry.dir, entry.basename, entry.basename, display_path, request.Target, entry.kind != .directory, request.Offset, page_size, &matched)) {
                has_more = true;
                break;
            }
        }
        if (has_more or budget.truncated) break;
    }
    return search_response(allocator, &out, request.Offset, has_more, budget);
}


fn search_root_seen(previous: []const []const u8, root: []const u8) bool {
    for (previous) |item| if (std.mem.eql(u8, item, root)) return true;
    return false;
}


fn search_response(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(class.SearchResult),
    offset: usize,
    has_more: bool,
    budget: class.SearchBudget
) !class.SearchResponse {
    const results = try out.toOwnedSlice(allocator);
    return .{ .Results = results, .NextOffset = if (has_more) offset + results.len else null, .Truncated = budget.truncated, .ScannedFiles = budget.scanned_files };
}


pub fn write_batch_archive(
    io: std.Io,
    allocator: std.mem.Allocator,
    share_dir: []const u8,
    items: []const class.FileRequest,
    writer: *std.Io.Writer
) !void {
    if (items.len == 0) return error.EmptySelection;
    for (items, 0 .. ) |item, idx| {
        if (!utils.access_item(item.Path) or !utils.confined_path(io, share_dir, item.Path, false)) return error.UnsafePath;
        const base = std.fs.path.basename(item.Path);
        for (items[0 .. idx]) |previous| if (std.mem.eql(u8, base, std.fs.path.basename(previous.Path))) return error.DuplicateArchiveName;
    }

    var root = try std.Io.Dir.cwd().openDir(io, share_dir, .{ .iterate = true, .follow_symlinks = false });
    defer root.close(io);
    var zw = class.ZipWriter.init(writer, 0);
    defer zw.deinit(allocator);
    for (items) |item| try zw.add_path_recursive(io, allocator, root, item.Path, std.fs.path.basename(item.Path));
    try zw.finish();
}


pub fn delete_file(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, items: []const class.FileRequest) ![]class.FileOperationResult {
    var results: std.ArrayList(class.FileOperationResult) = .empty;
    errdefer results.deinit(allocator);
    const root = std.Io.Dir.cwd().openDir(io, share_dir, .{}) catch {
        for (items) |it| try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "shared directory is unavailable" });
        return results.toOwnedSlice(allocator);
    };
    root.close(io);

    for (items) |it| {
        if (!utils.access_item(it.Path)) {
            try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "invalid or unsafe path" });
            continue;
        }

        var parent = utils.open_confined_parent(io, share_dir, it.Path) catch |err| {
            if (err == error.FileNotFound) {
                try results.append(allocator, .{ .Path = it.Path, .Success = true });
            }
            else {
                try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = @errorName(err) });
            }
            continue;
        };
        defer parent.close(io);

        const stat = parent.dir.statFile(io, parent.leaf, .{ .follow_symlinks = false }) catch |err| {
            if (err == error.FileNotFound) {
                try results.append(allocator, .{ .Path = it.Path, .Success = true });
            }
            else {
                try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = @errorName(err) });
            }
            continue;
        };
        if (stat.kind == .sym_link) {
            try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "symbolic links are not allowed" });
            continue;
        }

        parent.dir.deleteTree(io, parent.leaf) catch |err| {
            if (err != error.FileNotFound) {
                try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = @errorName(err) });
                continue;
            }
        };
        try results.append(allocator, .{ .Path = it.Path, .Success = true });
    }
    return results.toOwnedSlice(allocator);
}


pub fn make_dir(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, req: class.FileRequest) !class.FileOperationResult {
    if (!utils.access_super(req.CurrentDir) or !utils.access_name(req.Path) or !utils.confined_path(io, share_dir, req.CurrentDir, false)) return .{ .Path = req.Path, .Success = false, .Error = "invalid path or name" };
    const path = try utils.join_relative(allocator, req.CurrentDir, req.Path);
    defer allocator.free(path);
    if (utils.confined_path(io, share_dir, path, false)) return .{ .Path = req.Path, .Success = false, .Error = "destination exists" };
    if (!utils.make_confined_dir_path(io, allocator, share_dir, path)) return .{ .Path = req.Path, .Success = false, .Error = "directory creation failed" };
    return .{ .Path = req.Path, .Success = true };
}


pub fn rename_file(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, items: []const class.FileRename) ![]class.FileOperationResult {
    var results: std.ArrayList(class.FileOperationResult) = .empty;
    errdefer results.deinit(allocator);
    var root = std.Io.Dir.cwd().openDir(io, share_dir, .{}) catch {
        for (items) |it| try results.append(allocator, .{ .Path = it.OldName, .Success = false, .Error = "shared directory is unavailable" });
        return results.toOwnedSlice(allocator);
    };
    defer root.close(io);
    if (items.len == 0) return results.toOwnedSlice(allocator);
    const explicit_names = items[0].NewName.len > 0;

    var plans: std.ArrayList(class.RenamePlan) = .empty;
    defer {
        for (plans.items) |plan| {
            allocator.free(plan.source);
            allocator.free(plan.destination);
            allocator.free(plan.temporary);
        }
        plans.deinit(allocator);
    }
    var random: [16]u8 = undefined;
    io.random(&random);
    const token = std.fmt.bytesToHex(random, .lower);

    for (items, 0 .. ) |it, idx| {
        if ((it.NewName.len > 0) != explicit_names) return rename_failure_results(allocator, items, "cannot mix single and batch rename modes");
        if (!utils.access_super(it.CurrentDir) or !utils.access_name(it.OldName) or (!explicit_names and (std.mem.indexOfAny(u8, it.Prefix, "/\\\x00") != null or std.mem.indexOfAny(u8, it.Suffix, "/\\\x00") != null))) return rename_failure_results(allocator, items, "invalid path or name");
        const src = try utils.join_relative(allocator, it.CurrentDir, it.OldName);
        errdefer allocator.free(src);
        if (!utils.confined_path(io, share_dir, src, false)) return rename_failure_results(allocator, items, "invalid or unsafe source path");
        const stat = root.statFile(io, src, .{ .follow_symlinks = false }) catch return rename_failure_results(allocator, items, "source does not exist");
        if (stat.kind != .file and stat.kind != .directory) return rename_failure_results(allocator, items, "unsupported source type");

        const new_base = if (explicit_names) try allocator.dupe(u8, it.NewName) else if (stat.kind == .directory) try std.fmt.allocPrint(allocator, "{s}{d}{s}", .{ it.Prefix, idx + 1, it.Suffix }) else blk: {
            const ext = std.fs.path.extension(it.OldName);
            break :blk try std.fmt.allocPrint(allocator, "{s}{d}{s}{s}", .{ it.Prefix, idx + 1, it.Suffix, ext });
        };
        defer allocator.free(new_base);
        if (!utils.access_name(new_base)) return rename_failure_results(allocator, items, "invalid destination name");
        const dst = try utils.join_relative(allocator, it.CurrentDir, new_base);
        errdefer allocator.free(dst);
        if (!utils.confined_path(io, share_dir, dst, true)) return rename_failure_results(allocator, items, "invalid or unsafe destination");
        const temporary_base = try std.fmt.allocPrint(allocator, ".rename.{s}.{d}.tmp", .{ token, idx });
        defer allocator.free(temporary_base);
        const temporary = try utils.join_relative(allocator, it.CurrentDir, temporary_base);
        errdefer allocator.free(temporary);
        if (!utils.confined_path(io, share_dir, temporary, true)) return rename_failure_results(allocator, items, "cannot reserve temporary name");
        try plans.append(allocator, .{ .source = src, .destination = dst, .temporary = temporary, .display = it.OldName, .is_directory = stat.kind == .directory });
    }

    for (plans.items, 0 .. ) |plan, idx| {
        for (plans.items[0 .. idx]) |previous| if (std.mem.eql(u8, plan.source, previous.source) or std.mem.eql(u8, plan.destination, previous.destination)) {
            return rename_failure_results(allocator, items, "duplicate source or destination name");
        };
        if (std.mem.eql(u8, plan.source, plan.destination)) {
            plans.items[idx].state = .unchanged;
            continue;
        }
    }

    for (plans.items, 0 .. ) |plan, idx| {
        if (plan.state == .unchanged) continue;
        rename_without_replace(io, root, plan.source, root, plan.temporary, plan.is_directory) catch {
            rollback_rename_plans(io, root, plans.items);
            return rename_failure_results(allocator, items, "failed while staging batch rename");
        };
        plans.items[idx].state = .staged;
    }
    for (plans.items, 0 .. ) |plan, idx| {
        if (plan.state == .unchanged) continue;
        rename_without_replace(io, root, plan.temporary, root, plan.destination, plan.is_directory) catch {
            rollback_rename_plans(io, root, plans.items);
            return rename_failure_results(allocator, items, "failed while committing batch rename");
        };
        plans.items[idx].state = .committed;
    }
    for (items) |it| try results.append(allocator, .{ .Path = it.OldName, .Success = true });
    return results.toOwnedSlice(allocator);
}


fn rename_without_replace(
    io: std.Io,
    source_dir: std.Io.Dir,
    source: []const u8,
    destination_dir: std.Io.Dir,
    destination: []const u8,
    is_directory: bool
) !void {
    if (!is_directory) return source_dir.renamePreserve(source, destination_dir, destination, io);
    if (destination_dir.statFile(io, destination, .{ .follow_symlinks = false })) |_| return error.PathAlreadyExists else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    return source_dir.rename(source, destination_dir, destination, io);
}


fn rollback_rename_plans(io: std.Io, root: std.Io.Dir, plans: []class.RenamePlan) void {
    for (plans) |*plan| if (plan.state == .committed) {
        root.rename(plan.destination, root, plan.temporary, io) catch {};
        plan.state = .staged;
    };
    for (plans) |*plan| if (plan.state == .staged) {
        root.rename(plan.temporary, root, plan.source, io) catch {};
        plan.state = .pending;
    };
}


fn rename_failure_results(allocator: std.mem.Allocator, items: []const class.FileRename, message: []const u8) ![]class.FileOperationResult {
    var results: std.ArrayList(class.FileOperationResult) = .empty;
    errdefer results.deinit(allocator);
    for (items) |it| try results.append(allocator, .{ .Path = it.OldName, .Success = false, .Error = message });
    return results.toOwnedSlice(allocator);
}


pub fn copy_file(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, items: []const class.FileRequest) ![]class.FileOperationResult {
    return transfer_file(io, allocator, share_dir, items, .transfer_copy);
}


pub fn move_file(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, items: []const class.FileRequest) ![]class.FileOperationResult {
    return transfer_file(io, allocator, share_dir, items, .transfer_move);
}


fn transfer_file(
    io: std.Io,
    allocator: std.mem.Allocator,
    share_dir: []const u8,
    items: []const class.FileRequest,
    mode: class.TransferMode
) ![]class.FileOperationResult {
    var results: std.ArrayList(class.FileOperationResult) = .empty;
    errdefer results.deinit(allocator);
    const cwd = std.Io.Dir.cwd();
    var root = cwd.openDir(io, share_dir, .{}) catch {
        for (items) |it| try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "shared directory is unavailable" });
        return results.toOwnedSlice(allocator);
    };
    defer root.close(io);
    for (items) |it| {
        if (!utils.access_item(it.Path) or !utils.access_super(it.CurrentDir) or !utils.confined_path(io, share_dir, it.Path, false) or !utils.confined_path(io, share_dir, it.CurrentDir, false)) {
            try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "invalid or unsafe path" });
            continue;
        }
        const src = try utils.join_path(allocator, share_dir, &.{it.Path});
        defer allocator.free(src);
        const base = std.fs.path.basename(it.Path);
        const requested_dst_rel = utils.join_relative(allocator, it.CurrentDir, base) catch return error.OutOfMemory;
        defer allocator.free(requested_dst_rel);
        if (!utils.confined_path(io, share_dir, requested_dst_rel, true)) {
            try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "invalid or unsafe destination" });
            continue;
        }
        const src_stat = cwd.statFile(io, src, .{ .follow_symlinks = false }) catch {
            try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "source does not exist" });
            continue;
        };
        if (mode == .transfer_move and std.mem.eql(u8, it.Path, requested_dst_rel)) {
            try results.append(allocator, .{ .Path = it.Path, .Success = true });
            continue;
        }
        if (src_stat.kind == .directory and !std.mem.eql(u8, it.Path, requested_dst_rel) and utils.path_contains_or_equal(it.Path, requested_dst_rel)) {
            try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "invalid destination inside source" });
            continue;
        }
        const dst_rel = try available_destination(io, allocator, root, it.CurrentDir, base, src_stat.kind == .directory);
        defer allocator.free(dst_rel);
        switch (mode) {
            .transfer_copy => {
                if (src_stat.kind == .directory) {
                    const directory_dst = try utils.join_path(allocator, share_dir, &.{dst_rel});
                    defer allocator.free(directory_dst);
                    cwd.createDir(io, directory_dst, .default_dir) catch {
                        try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "destination changed before directory copy" });
                        continue;
                    };
                    utils.copy_directory_contents(io, allocator, src, directory_dst) catch {
                        cwd.deleteTree(io, directory_dst) catch {};
                        try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "directory copy failed" });
                        continue;
                    };
                    try results.append(allocator, .{ .Path = it.Path, .Success = true });
                    continue;
                }
                const tmp_rel = try std.fmt.allocPrint(allocator, "{s}.copy.{d}.{d}.tmp", .{ dst_rel, std.Thread.getCurrentId(), std.Io.Clock.real.now(io).toNanoseconds() });
                defer allocator.free(tmp_rel);
                const tmp = try utils.join_path(allocator, share_dir, &.{tmp_rel});
                defer allocator.free(tmp);
                utils.copy_any(io, allocator, src, tmp) catch {
                    cwd.deleteTree(io, tmp) catch {};
                    try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "copy failed" });
                    continue;
                };
                root.renamePreserve(tmp_rel, root, dst_rel, io) catch {
                    cwd.deleteTree(io, tmp) catch {};
                    try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "destination exists or copy failed" });
                    continue;
                };
            },
            .transfer_move => {
                if (src_stat.kind == .directory) {
                    var source_parent = utils.open_confined_parent(io, share_dir, it.Path) catch {
                        try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "source changed before directory move" });
                        continue;
                    };
                    defer source_parent.close(io);
                    var destination_parent = utils.open_confined_parent(io, share_dir, dst_rel) catch {
                        try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "destination changed before directory move" });
                        continue;
                    };
                    defer destination_parent.close(io);
                    rename_without_replace(io, source_parent.dir, source_parent.leaf, destination_parent.dir, destination_parent.leaf, true) catch |err| switch (err) {
                        error.CrossDevice => {
                            destination_parent.dir.createDir(io, destination_parent.leaf, .default_dir) catch {
                                try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "destination changed before directory move" });
                                continue;
                            };
                            copy_directory_confined(io, source_parent.dir, source_parent.leaf, destination_parent.dir, destination_parent.leaf) catch {
                                destination_parent.dir.deleteTree(io, destination_parent.leaf) catch {};
                                try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "directory move failed while copying" });
                                continue;
                            };
                            source_parent.dir.deleteTree(io, source_parent.leaf) catch {
                                try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "directory copied but source cleanup failed" });
                                continue;
                            };
                        },
                        else => {
                            try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "destination changed or move failed" });
                            continue;
                        },
                    };
                    try results.append(allocator, .{ .Path = it.Path, .Success = true });
                    continue;
                }
                root.renamePreserve(it.Path, root, dst_rel, io) catch {
                    try results.append(allocator, .{ .Path = it.Path, .Success = false, .Error = "destination changed or move failed" });
                    continue;
                };
            },
        }
        try results.append(allocator, .{ .Path = it.Path, .Success = true });
    }
    return results.toOwnedSlice(allocator);
}


fn copy_directory_confined(
    io: std.Io,
    source_parent: std.Io.Dir,
    source_name: []const u8,
    destination_parent: std.Io.Dir,
    destination_name: []const u8
) !void {
    var source = try source_parent.openDir(io, source_name, .{ .iterate = true, .follow_symlinks = false });
    defer source.close(io);
    var destination = try destination_parent.openDir(io, destination_name, .{ .iterate = true, .follow_symlinks = false });
    defer destination.close(io);
    try copy_directory_contents_confined(io, source, destination);
}


fn copy_directory_contents_confined(io: std.Io, source: std.Io.Dir, destination: std.Io.Dir) !void {
    var iterator = source.iterate();
    while (try iterator.next(io)) |entry| {
        const kind = if (entry.kind == .unknown) (try source.statFile(io, entry.name, .{ .follow_symlinks = false })).kind else entry.kind;
        switch (kind) {
            .directory => {
                try destination.createDir(io, entry.name, .default_dir);
                var source_child = try source.openDir(io, entry.name, .{ .iterate = true, .follow_symlinks = false });
                defer source_child.close(io);
                var destination_child = try destination.openDir(io, entry.name, .{ .iterate = true, .follow_symlinks = false });
                defer destination_child.close(io);
                try copy_directory_contents_confined(io, source_child, destination_child);
            },
            .file => try copy_file_confined(io, source, destination, entry.name),
            .sym_link => return error.UnsafePath,
            else => return error.UnsupportedFileType,
        }
    }
}


fn copy_file_confined(io: std.Io, source: std.Io.Dir, destination: std.Io.Dir, name: []const u8) !void {
    const source_file = try source.openFile(io, name, .{ .allow_directory = false, .follow_symlinks = false, .resolve_beneath = true });
    defer source_file.close(io);
    const stat = try source_file.stat(io);
    const destination_file = try destination.createFile(io, name, .{ .exclusive = true, .permissions = stat.permissions });
    defer destination_file.close(io);
    var reader_buffer: [64 * 1024]u8 = undefined;
    var writer_buffer: [64 * 1024]u8 = undefined;
    var buffer: [64 * 1024]u8 = undefined;
    var reader = source_file.reader(io, &reader_buffer);
    var writer = destination_file.writer(io, &writer_buffer);
    while (true) {
        const count = try reader.interface.readSliceShort(&buffer);
        if (count == 0) break;
        try writer.interface.writeAll(buffer[0 .. count]);
    }
    try writer.interface.flush();
}


fn available_destination(
    io: std.Io,
    allocator: std.mem.Allocator,
    root: std.Io.Dir,
    current_dir: []const u8,
    base: []const u8,
    is_directory: bool
) ![]u8 {
    const requested = try utils.join_relative(allocator, current_dir, base);
    _ = root.statFile(io, requested, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return requested,
        else => {
            allocator.free(requested);
            return err;
        },
    };
    allocator.free(requested);

    const ext = if (is_directory) "" else std.fs.path.extension(base);
    const stem = base[0 .. base.len - ext.len];
    var index: usize = 1;
    while (index < 10000) : (index = index + 1) {
        const candidate_base = try std.fmt.allocPrint(allocator, "{s} ({d}){s}", .{ stem, index, ext });
        defer allocator.free(candidate_base);
        const candidate = try utils.join_relative(allocator, current_dir, candidate_base);
        _ = root.statFile(io, candidate, .{ .follow_symlinks = false }) catch |err| switch (err) {
            error.FileNotFound => return candidate,
            else => {
                allocator.free(candidate);
                return err;
            },
        };
        allocator.free(candidate);
    }
    return error.PathAlreadyExists;
}


fn finish_uploaded_tmp(
    io: std.Io,
    allocator: std.mem.Allocator,
    cfg: *const class.AppConfig,
    current_dir: []const u8,
    rel: []const u8,
    tmp: []const u8
) !bool {
    if (!utils.access_item(rel) or !utils.access_super(current_dir)) return false;
    const dst = try utils.join_path(allocator, cfg.store_dir, &.{ current_dir, rel });
    defer allocator.free(dst);
    const dst_rel = try utils.join_relative(allocator, current_dir, rel);
    defer allocator.free(dst_rel);
    if (!utils.make_confined_dir_path(io, allocator, cfg.store_dir, std.fs.path.dirname(dst_rel) orelse ".")) return false;
    if (!utils.confined_path(io, cfg.store_dir, dst_rel, true)) return false;
    const cwd = std.Io.Dir.cwd();
    var root = try cwd.openDir(io, cfg.store_dir, .{});
    defer root.close(io);
    const tmp_rel = std.fs.path.basename(tmp);
    root.renamePreserve(tmp_rel, root, dst_rel, io) catch return false;
    return true;
}


fn append_search_page_result(
    io: std.Io,
    allocator: std.mem.Allocator,
    scratch_allocator: std.mem.Allocator,
    out: *std.ArrayList(class.SearchResult),
    dir: std.Io.Dir,
    leaf: []const u8,
    name: []const u8,
    display_path: []const u8,
    target: []const u8,
    search_content: bool,
    offset: usize,
    limit: usize,
    matched: *usize
) !bool {
    const name_matches = std.ascii.indexOfIgnoreCase(name, target) != null;
    var matches = if (search_content) try utils.find_matching_text_snippets(
        io,
        scratch_allocator,
        allocator,
        dir,
        leaf,
        target,
        class.search_max_file_read_bytes,
        if (offset > matched.*) offset - matched.* else 0,
        limit - out.items.len
    ) else class.MatchingTextSnippets{
        .items = try allocator.alloc([]u8, 0),
        .match_count = 0,
        .has_more = false
    };
    var transferred: usize = 0;
    defer {
        for (matches.items[transferred .. ]) |snippet| allocator.free(snippet);
        allocator.free(matches.items);
    }

    matched.* = matched.* + matches.match_count;
    for (matches.items) |description| {
        const path = try allocator.dupe(u8, display_path);
        out.append(
            allocator,
            .{ .Path = path, .Description = description }
        ) catch |err| {
            allocator.free(path);
            return err;
        };
        transferred = transferred + 1;
    }
    if (matches.has_more) return true;
    if (matches.match_count > 0 or !name_matches) return false;

    matched.* = matched.* + 1;
    if (matched.* <= offset) return false;
    if (out.items.len >= limit) return true;

    const path = try allocator.dupe(u8, display_path);
    errdefer allocator.free(path);
    try out.append(
        allocator,
        .{ .Path = path, .Description = "" }
    );
    return false;
}
