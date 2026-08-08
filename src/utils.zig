const std = @import("std");
const httpz = @import("httpz");
const builtin = @import("builtin");
const class = @import("class.zig");
const assets = @import("assets.zig");


pub fn listen_address(host: []const u8, port: u16) !httpz.Config.Address {
    const trimmed = std.mem.trim(u8, host, " \t");
    if (trimmed.len == 0 or std.ascii.eqlIgnoreCase(trimmed, "localhost")) {
        return .localhost(port);
    }
    if (std.mem.eql(u8, trimmed, "*") or std.ascii.eqlIgnoreCase(trimmed, "all") or std.mem.eql(u8, trimmed, "0.0.0.0")) {
        return .all(port);
    }
    return .{ .ip = try std.Io.net.IpAddress.parse(trimmed, port) };
}


pub fn upload_request_limit(cfg: *const class.AppConfig) usize {
    const file_limit: usize = @intCast(@max(cfg.max_bytes(), 0));
    return std.math.add(usize, file_limit, 64 * 1024) catch std.math.maxInt(usize);
}


pub fn format_time(allocator: std.mem.Allocator, time: std.Io.Timestamp) ![]u8 {
    const seconds = local_second(time.toSeconds());
    const ymdhms = UTC_to_YMDHMS(seconds);
    return std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{ ymdhms.year, ymdhms.month, ymdhms.day, ymdhms.hour, ymdhms.minute, ymdhms.second });
}


pub fn write_file_size(w: *std.Io.Writer, n: i64) !void {
    if (n < 1024) return w.print("{d} B", .{n});
    const f = @as(f64, @floatFromInt(n));
    if (n < 1 << 20) return w.print("{d:.2} KB", .{f / 1024.0});
    if (n < 1 << 30) return w.print("{d:.2} MB", .{f / (1024.0 * 1024.0)});
    if (n < 1 << 40) return w.print("{d:.2} GB", .{f / (1024.0 * 1024.0 * 1024.0)});
    return w.print("{d:.2} TB", .{f / (1024.0 * 1024.0 * 1024.0 * 1024.0)});
}


pub fn format_file_size(allocator: std.mem.Allocator, n: i64) ![]u8 {
    var buffer: [32]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buffer);
    try write_file_size(&fbs, n);
    return allocator.dupe(u8, fbs.buffered());
}


pub fn join_path(allocator: std.mem.Allocator, dir: []const u8, parts: []const []const u8) ![]u8 {
    var list: std.ArrayList([]const u8) = .empty;
    defer list.deinit(allocator);
    try list.append(allocator, dir);
    for (parts) |part| if (part.len > 0) try list.append(allocator, part);
    return std.fs.path.join(allocator, list.items);
}


pub fn join_relative(allocator: std.mem.Allocator, dir: []const u8, path: []const u8) ![]u8 {
    if (std.mem.eql(u8, dir, ".")) return allocator.dupe(u8, path);
    return std.fs.path.join(allocator, &.{ dir, path });
}


pub fn access_super(path: []const u8) bool {
    if (path.len == 0 or std.mem.indexOfScalar(u8, path, 0) != null) return false;
    if (std.fs.path.isSep(path[0]) or std.fs.path.isAbsolute(path) or (builtin.os.tag == .windows and is_windows_drive_prefix(path))) return false;
    if (std.mem.eql(u8, path, ".")) return true;
    const separators = if (builtin.os.tag == .windows) "/\\" else "/";
    var components = std.mem.splitAny(u8, path, separators);
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    return true;
}


pub fn access_item(path: []const u8) bool {
    return access_super(path) and !std.mem.eql(u8, path, ".") and !is_internal_temporary_path(path);
}


pub fn is_internal_temporary_name(name: []const u8) bool {
    if (std.mem.startsWith(u8, name, ".upload.") and std.mem.endsWith(u8, name, ".tmp")) {
        const token = name[8 .. (name.len - 4)];
        var fields = std.mem.splitScalar(u8, token, '.');
        var count: usize = 0;
        while (fields.next()) |field| {
            if (field.len == 0) return false;
            for (field) |byte| if (!std.ascii.isDigit(byte)) return false;
            count = count + 1;
        }
        return count == 3;
    }
    if (std.mem.startsWith(u8, name, ".download.") and std.mem.endsWith(u8, name, ".zip")) {
        const token = name[10 .. (name.len - 4)];
        if (token.len != 32) return false;
        for (token) |byte| if (!std.ascii.isHex(byte)) return false;
        return true;
    }
    if (std.mem.startsWith(u8, name, ".rename.") and std.mem.endsWith(u8, name, ".tmp")) {
        const token_and_index = name[8 .. (name.len - 4)];
        const separator = std.mem.lastIndexOfScalar(u8, token_and_index, '.') orelse return false;
        const token = token_and_index[0 .. separator];
        const index = token_and_index[(separator + 1) .. ];
        if (token.len != 32 or index.len == 0) return false;
        for (token) |byte| if (!std.ascii.isHex(byte)) return false;
        for (index) |byte| if (!std.ascii.isDigit(byte)) return false;
        return true;
    }
    return false;
}


pub fn is_internal_temporary_path(path: []const u8) bool {
    const separators = if (builtin.os.tag == .windows) "/\\" else "/";
    var components = std.mem.tokenizeAny(u8, path, separators);
    while (components.next()) |component| if (is_internal_temporary_name(component)) return true;
    return false;
}


pub fn access_name(name: []const u8) bool {
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, 0) != null or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) return false;
    for (name) |byte| if (std.fs.path.isSep(byte)) return false;
    return true;
}


pub fn open_confined_parent(io: std.Io, share_dir: []const u8, path: []const u8) !class.ConfinedParent {
    if (!access_item(path)) return error.UnsafePath;
    var current = try std.Io.Dir.cwd().openDir(io, share_dir, .{});
    errdefer current.close(io);

    const separators = if (builtin.os.tag == .windows) "/\\" else "/";
    var components = std.mem.splitAny(u8, path, separators);
    var leaf = components.next() orelse return error.UnsafePath;
    while (components.next()) |next_component| {
        const next = try current.openDir(io, leaf, .{ .follow_symlinks = false });
        current.close(io);
        current = next;
        leaf = next_component;
    }
    return .{ .dir = current, .leaf = leaf };
}


pub fn open_confined_dir(io: std.Io, share_dir: []const u8, path: []const u8, iterate: bool) !std.Io.Dir {
    if (!access_super(path)) return error.UnsafePath;
    if (std.mem.eql(u8, path, ".")) return std.Io.Dir.cwd().openDir(io, share_dir, .{ .iterate = iterate });
    var parent = try open_confined_parent(io, share_dir, path);
    defer parent.close(io);
    return parent.dir.openDir(io, parent.leaf, .{ .iterate = iterate, .follow_symlinks = false });
}


pub fn open_confined_file(io: std.Io, share_dir: []const u8, path: []const u8) !std.Io.File {
    var parent = try open_confined_parent(io, share_dir, path);
    defer parent.close(io);
    return parent.dir.openFile(io, parent.leaf, .{ .follow_symlinks = false, .resolve_beneath = true });
}


pub fn confined_path(io: std.Io, share_dir: []const u8, path: []const u8, allow_missing_leaf: bool) bool {
    if (!access_super(path)) return false;
    var root = std.Io.Dir.cwd().openDir(io, share_dir, .{}) catch return false;
    defer root.close(io);
    if (std.mem.eql(u8, path, ".")) return true;

    const separators = if (builtin.os.tag == .windows) "/\\" else "/";
    var components = std.mem.splitAny(u8, path, separators);
    while (components.next()) |component| {
        const last = components.peek() == null;
        const stat = root.statFile(io, component, .{ .follow_symlinks = false }) catch {
            return allow_missing_leaf and last;
        };
        if (stat.kind == .sym_link) return false;
        if (last) return true;
        if (stat.kind != .directory) return false;
        const next = root.openDir(io, component, .{ .follow_symlinks = false }) catch return false;
        root.close(io);
        root = next;
    }
    return false;
}


pub fn make_confined_dir_path(io: std.Io, allocator: std.mem.Allocator, share_dir: []const u8, path: []const u8) bool {
    if (!access_super(path)) return false;
    var root = std.Io.Dir.cwd().openDir(io, share_dir, .{}) catch return false;
    defer root.close(io);
    if (std.mem.eql(u8, path, ".")) return true;

    var missing = false;
    const separators = if (builtin.os.tag == .windows) "/\\" else "/";
    var components = std.mem.splitAny(u8, path, separators);
    while (components.next()) |component| {
        if (missing) continue;
        const stat = root.statFile(io, component, .{ .follow_symlinks = false }) catch {
            missing = true;
            continue;
        };
        if (stat.kind != .directory) return false;
        const next = root.openDir(io, component, .{ .follow_symlinks = false }) catch return false;
        root.close(io);
        root = next;
    }
    if (!missing) return true;
    const full = join_path(allocator, share_dir, &.{path}) catch return false;
    defer allocator.free(full);
    std.Io.Dir.cwd().createDirPath(io, full) catch return false;
    return confined_path(io, share_dir, path, false);
}


pub fn path_contains_or_equal(parent: []const u8, child: []const u8) bool {
    var parent_i: usize = 0;
    var child_i: usize = 0;
    while (true) {
        const parent_part = next_path_component(parent, &parent_i) orelse return true;
        const child_part = next_path_component(child, &child_i) orelse return false;
        if (!std.mem.eql(u8, parent_part, child_part)) return false;
    }
}


pub fn parse_flags(args: [][:0]const u8, cfg: *class.AppConfig, state: *class.AppState) bool {
    var i: usize = 1;
    while (i < args.len) : (i = i + 2) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-help")) return false;
        if (i + 1 >= args.len) return false;

        const v = args[i + 1];
        if (std.mem.eql(u8, arg, "--ip") or std.mem.eql(u8, arg, "-ip")) cfg.host_ipv4 = v else if (std.mem.eql(u8, arg, "--port") or std.mem.eql(u8, arg, "-port")) cfg.host_port = v else if (std.mem.eql(u8, arg, "--share") or std.mem.eql(u8, arg, "-share")) {
            cfg.share_dir = v;
            cfg.store_dir = v;
        }
        else if (std.mem.eql(u8, arg, "--store") or std.mem.eql(u8, arg, "-store")) cfg.store_dir = v else if (std.mem.eql(u8, arg, "--max") or std.mem.eql(u8, arg, "-max")) cfg.limit_max = v else if (std.mem.eql(u8, arg, "--login") or std.mem.eql(u8, arg, "-login")) cfg.login_pwd = v else if (std.mem.eql(u8, arg, "--button") or std.mem.eql(u8, arg, "-button")) {
            if (!parse_button_flags(v, state)) return false;
        } else return false;
    }
    return true;
}


pub fn dir_hash(io: std.Io, allocator: std.mem.Allocator, dir: []const u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    var d = std.Io.Dir.cwd().openDir(io, dir, .{ .iterate = true }) catch return 0;
    defer d.close(io);
    var walker = d.walk(allocator) catch return 0;
    defer walker.deinit();

    while (walker.next(io) catch null) |entry| {
        if (is_internal_temporary_path(entry.path)) continue;
        hasher.update(entry.path);
        if (entry.kind == .directory) {
            hasher.update("/");
            continue;
        }
        const stat = entry.dir.statFile(io, entry.basename, .{}) catch continue;
        const size_bytes = std.mem.asBytes(&stat.size);
        hasher.update(size_bytes);
        const time_bytes = std.mem.asBytes(&stat.mtime.nanoseconds);
        hasher.update(time_bytes);
    }
    return hasher.final();
}


pub fn lookup_web_option(state: *class.AppState, name: []const u8) ?bool {
    if (std.mem.eql(u8, name, "ANNOUNCEMENT_STATUS_")) return state.status_announcement;
    if (std.mem.eql(u8, name, "UPLOAD_STATUS_")) return state.status_upload;
    if (std.mem.eql(u8, name, "SEARCH_STATUS_")) return state.status_search;
    if (std.mem.eql(u8, name, "DELETE_STATUS_")) return state.status_delete;
    if (std.mem.eql(u8, name, "MKDIR_STATUS_")) return state.status_mkdir;
    if (std.mem.eql(u8, name, "COPY_STATUS_")) return state.status_copy;
    if (std.mem.eql(u8, name, "MOVE_STATUS_")) return state.status_move;
    if (std.mem.eql(u8, name, "RENAME_STATUS_")) return state.status_rename;
    return null;
}


pub fn find_asset(path: []const u8) ?class.UI {
    for (assets.UI) |ui| if (std.mem.eql(u8, ui.path, path)) return ui;
    return null;
}


pub fn block_sigint() class.SigintSet {
    if (comptime builtin.os.tag == .windows) {
        class.WindowsSigint.received.store(false, .release);
        if (!class.WindowsSigint.SetConsoleCtrlHandler(class.WindowsSigint.console, std.os.windows.BOOL.TRUE).toBool()) @panic("failed to register console control handler");
        return {};
    }
    var set = std.posix.sigemptyset();
    std.posix.sigaddset(&set, .INT);
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &set, null);
    return set;
}


pub fn wait_for_sigint(io: std.Io, set: *const class.SigintSet) void {
    if (comptime builtin.os.tag == .windows) {
        while (!class.WindowsSigint.received.load(.acquire)) std.Io.sleep(io, .fromMilliseconds(100), .awake) catch {};
        return;
    }
    var signal: c_int = 0;
    while (std.c.sigwait(@constCast(set), &signal) == 0) {
        if (signal == @intFromEnum(std.posix.SIG.INT)) return;
    }
}


pub fn folder_size_count(io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir) !class.FileSizeCount {
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var total_size: i64 = 0;
    var total_count: i64 = 0;
    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory or entry.kind == .sym_link) continue;
        const child = entry.dir.openFile(io, entry.basename, .{ .follow_symlinks = false, .resolve_beneath = true }) catch continue;
        const stat = child.stat(io) catch {
            child.close(io);
            continue;
        };
        child.close(io);
        total_size = total_size + @as(@TypeOf(total_size), @intCast(stat.size));
        total_count = total_count + 1;
    }
    return .{ .size = total_size, .count = total_count };
}


pub fn ago_time(io: std.Io, allocator: std.mem.Allocator, time: std.Io.Timestamp) ![]u8 {
    const seconds = time.toSeconds();
    const now = std.Io.Clock.real.now(io).toSeconds();
    const diff = now - seconds;
    const ymdhms = UTC_to_YMDHMS(local_second(seconds));
    const weekday = zeller_weekday(@as(i32, ymdhms.year), @as(i32, ymdhms.month), @as(i32, ymdhms.day));

    const buckets = [_]class.ChineseTime{ .{ .interval = 60, .label = "刚刚" }, .{ .interval = 180, .label = "一分钟前" }, .{ .interval = 900, .label = "三分钟前" }, .{ .interval = 1800, .label = "一刻钟前" }, .{ .interval = 3600, .label = "半小时前" }, .{ .interval = 7200, .label = "一小时前" }, .{ .interval = 43200, .label = "一个时辰前" }, .{ .interval = 86400, .label = "半天前" }, .{ .interval = 172800, .label = "一天前" }, .{ .interval = 259200, .label = "两天前" }, .{ .interval = 604800, .label = "三天前" }, .{ .interval = 1296000, .label = "一周前" }, .{ .interval = 2592000, .label = "半个月前" } };
    for (buckets) |b| if (diff < b.interval) {
        return std.fmt.allocPrint(allocator, "{s}（{s}）", .{ b.label, weekday });
    };

    const now_ymdhms = UTC_to_YMDHMS(local_second(now));
    var years: i32 = @as(i32, now_ymdhms.year) - @as(i32, ymdhms.year);
    if (now_ymdhms.month < ymdhms.month or (now_ymdhms.month == ymdhms.month and now_ymdhms.day < ymdhms.day)) years = years - 1;
    if (years < 1) {
        var months: i32 = (@as(i32, now_ymdhms.year) - @as(i32, ymdhms.year)) * 12 + (@as(i32, now_ymdhms.month) - @as(i32, ymdhms.month));
        if (now_ymdhms.day < ymdhms.day) months = months - 1;
        if (months < 0) months = 0;
        return std.fmt.allocPrint(allocator, "{d} 个月前（{s}）", .{ months, weekday });
    }
    return std.fmt.allocPrint(allocator, "{d} 年前（{s}）", .{ years, weekday });
}


pub fn exists_path(io: std.Io, p: []const u8) bool {
    std.Io.Dir.cwd().access(io, p, .{}) catch return false;
    return true;
}


pub fn copy_any(io: std.Io, allocator: std.mem.Allocator, src: []const u8, dst: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const stat = try cwd.statFile(io, src, .{ .follow_symlinks = false });
    if (stat.kind == .sym_link) return error.UnsafePath;

    if (stat.kind != .directory) {
        if (std.fs.path.dirname(dst)) |dd| cwd.createDirPath(io, dd) catch {};
        try cwd.copyFile(src, cwd, dst, io, .{ .replace = false });
        return;
    }
    try cwd.createDir(io, dst, .default_dir);
    var dir = try cwd.openDir(io, src, .{ .iterate = true, .follow_symlinks = false });
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |e| {
        const child_src = try std.fs.path.join(allocator, &.{ src, e.name });
        defer allocator.free(child_src);
        const child_dst = try std.fs.path.join(allocator, &.{ dst, e.name });
        defer allocator.free(child_dst);
        try copy_any(io, allocator, child_src, child_dst);
    }
}


pub fn copy_directory_contents(io: std.Io, allocator: std.mem.Allocator, src: []const u8, dst: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const stat = try cwd.statFile(io, src, .{ .follow_symlinks = false });
    if (stat.kind != .directory) return error.NotDir;
    var dir = try cwd.openDir(io, src, .{ .iterate = true, .follow_symlinks = false });
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        const child_src = try std.fs.path.join(allocator, &.{ src, entry.name });
        defer allocator.free(child_src);
        const child_dst = try std.fs.path.join(allocator, &.{ dst, entry.name });
        defer allocator.free(child_dst);
        try copy_any(io, allocator, child_src, child_dst);
    }
}


pub fn is_windows_drive_prefix(path: []const u8) bool {
    return path.len >= 2 and std.ascii.isAlphabetic(path[0]) and path[1] == ':';
}


pub fn validate_relative_path(path: []const u8) !void {
    if (path.len == 0 or std.fs.path.isSep(path[0]) or (builtin.os.tag == .windows and is_windows_drive_prefix(path))) return error.InvalidPath;
    const separators = if (builtin.os.tag == .windows) "/\\" else "/";
    var components = std.mem.splitAny(u8, path, separators);
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return error.InvalidPath;
    }
}


pub fn multipurpose_internet_mail_extensions(path: []const u8) []const u8 {
    const extension = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(extension, ".html")) return "text/html; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".htm")) return "text/html; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".css")) return "text/css; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".js")) return "application/javascript; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".mjs")) return "application/javascript; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".txt")) return "text/plain; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".md")) return "text/markdown; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".csv")) return "text/csv; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".xml")) return "application/xml; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".json")) return "application/json; charset=utf-8";
    if (std.ascii.eqlIgnoreCase(extension, ".pdf")) return "application/pdf";
    if (std.ascii.eqlIgnoreCase(extension, ".svg")) return "image/svg+xml";
    if (std.ascii.eqlIgnoreCase(extension, ".png")) return "image/png";
    if (std.ascii.eqlIgnoreCase(extension, ".jpg")) return "image/jpeg";
    if (std.ascii.eqlIgnoreCase(extension, ".jpeg")) return "image/jpeg";
    if (std.ascii.eqlIgnoreCase(extension, ".gif")) return "image/gif";
    if (std.ascii.eqlIgnoreCase(extension, ".webp")) return "image/webp";
    if (std.ascii.eqlIgnoreCase(extension, ".bmp")) return "image/bmp";
    if (std.ascii.eqlIgnoreCase(extension, ".ico")) return "image/x-icon";
    if (std.ascii.eqlIgnoreCase(extension, ".mp3")) return "audio/mpeg";
    if (std.ascii.eqlIgnoreCase(extension, ".wav")) return "audio/wav";
    if (std.ascii.eqlIgnoreCase(extension, ".mp4")) return "video/mp4";
    if (std.ascii.eqlIgnoreCase(extension, ".webm")) return "video/webm";
    if (std.ascii.eqlIgnoreCase(extension, ".mov")) return "video/quicktime";
    if (std.ascii.eqlIgnoreCase(extension, ".woff")) return "font/woff";
    if (std.ascii.eqlIgnoreCase(extension, ".woff2")) return "font/woff2";
    return "application/octet-stream";
}


pub fn is_probably_plain_text(sample: []const u8, sample_reached_eof: bool) bool {
    if (sample.len == 0) return true;
    if (std.mem.indexOfScalar(u8, sample, 0) != null) return false;

    var uncommon_controls: usize = 0;
    for (sample) |byte| {
        if (byte < 0x20 and byte != '\t' and byte != '\n' and byte != '\r' and byte != 0x0c and byte != 0x1b) {
            uncommon_controls = uncommon_controls + 1;
        }
    }
    if (uncommon_controls * 100 > sample.len) return false;

    if (std.unicode.utf8ValidateSlice(sample)) return true;
    if (sample_reached_eof) return false;

    var trim: usize = 1;
    while (trim <= 3 and trim < sample.len) : (trim = trim + 1) {
        if (std.unicode.utf8ValidateSlice(sample[0 .. sample.len - trim])) return true;
    }
    return false;
}


pub fn is_text_candidate(path: []const u8) bool {
    const mime = multipurpose_internet_mail_extensions(path);
    return is_textual_mime(mime) or std.mem.eql(u8, mime, "application/octet-stream");
}


pub fn is_textual_mime(mime: []const u8) bool {
    return std.mem.startsWith(u8, mime, "text/") or
        std.mem.startsWith(u8, mime, "application/javascript") or
        std.mem.startsWith(u8, mime, "application/json") or
        std.mem.startsWith(u8, mime, "application/xml") or
        std.mem.startsWith(u8, mime, "image/svg+xml");
}


pub fn is_viewable_mime(mime: []const u8) bool {
    if (is_textual_mime(mime)) return true;
    if (std.mem.startsWith(u8, mime, "image/")) return true;
    if (std.mem.startsWith(u8, mime, "audio/")) return true;
    if (std.mem.startsWith(u8, mime, "video/")) return true;
    return std.mem.startsWith(u8, mime, "application/pdf");
}


pub fn relative_search_path(current_dir: []const u8, path: []const u8) ?[]const u8 {
    if (current_dir.len == 0 or std.mem.eql(u8, current_dir, ".")) return path;
    if (!std.mem.startsWith(u8, path, current_dir)) return null;
    if (path.len <= current_dir.len or path[current_dir.len] != std.fs.path.sep) return null;
    return path[current_dir.len + 1 .. ];
}


pub fn find_matching_text_snippet(io: std.Io, read_allocator: std.mem.Allocator, result_allocator: std.mem.Allocator, dir: std.Io.Dir, name: []const u8, target: []const u8, max_read_bytes: usize) !?[]u8 {
    if (!is_text_candidate(name)) return null;
    if (!file_starts_as_plain_text(io, dir, name)) return null;
    const file = dir.openFile(io, name, .{ .follow_symlinks = false, .resolve_beneath = true }) catch return null;
    defer file.close(io);
    var buffer: [8 * 1024]u8 = undefined;
    var reader = file.reader(io, &buffer);
    const content = reader.interface.allocRemaining(read_allocator, .limited(max_read_bytes)) catch return null;
    defer read_allocator.free(content);
    if (!is_probably_plain_text(content, true)) return null;

    const match_index = std.ascii.indexOfIgnoreCase(content, target) orelse return null;
    const line_start = if (std.mem.lastIndexOfScalar(u8, content[0 .. match_index], '\n')) |i| i + 1 else 0;
    const line_end = std.mem.indexOfScalarPos(u8, content, match_index + target.len, '\n') orelse content.len;

    var snippet_start = if (match_index > line_start + 120) match_index - 120 else line_start;
    while (snippet_start < match_index and content[snippet_start] & 0xc0 == 0x80) snippet_start = snippet_start + 1;
    var snippet_end = @min(line_end, match_index + target.len + 200);
    while (snippet_end > match_index + target.len and snippet_end < content.len and content[snippet_end] & 0xc0 == 0x80) snippet_end = snippet_end - 1;
    const snippet = std.mem.trim(u8, content[snippet_start .. snippet_end], " \t\r");
    return try result_allocator.dupe(u8, snippet);
}


fn file_starts_as_plain_text(io: std.Io, dir: std.Io.Dir, name: []const u8) bool {
    const file = dir.openFile(io, name, .{ .follow_symlinks = false, .resolve_beneath = true }) catch return false;
    defer file.close(io);

    var reader_buffer: [8 * 1024]u8 = undefined;
    var reader = file.reader(io, &reader_buffer);
    var sample: [64 * 1024]u8 = undefined;
    const sample_len = reader.interface.readSliceShort(&sample) catch return false;
    return is_probably_plain_text(sample[0 .. sample_len], sample_len < sample.len);
}


fn local_second(seconds: i64) i64 {
    return seconds + 8 * 60 * 60;
}


fn zeller_weekday(year: i32, month: i32, day: i32) []const u8 {
    const names = [_][]const u8{ "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六" };
    var y: i32 = undefined;
    var m: i32 = undefined;
    var c: i32 = undefined;
    if (month >= 3) {
        m = month;
        y = @mod(year, 100);
        c = @divTrunc(year, 100);
    }
    else {
        m = month + 12;
        y = @mod(year - 1, 100);
        c = @divTrunc(year - 1, 100);
    }
    var w: i32 = y + @divTrunc(y, 4) + @divTrunc(c, 4) - 2 * c + @divTrunc(26 * (m + 1), 10) + day - 1;
    w = @mod(@mod(w, 7) + 7, 7);
    return names[@as(usize, @intCast(w))];
}


fn UTC_to_YMDHMS(seconds: i64) class.StdTimeFormat {
    const positive: u64 = if (seconds < 0) 0 else @intCast(seconds);
    const es = std.time.epoch.EpochSeconds{ .secs = positive };
    const ed = es.getEpochDay();
    const ds = es.getDaySeconds();
    const yd = ed.calculateYearDay();
    const md = yd.calculateMonthDay();
    return .{ .year = @intCast(yd.year), .month = @intFromEnum(md.month), .day = @as(u5, @intCast(@as(u6, md.day_index) + 1)), .hour = ds.getHoursIntoDay(), .minute = ds.getMinutesIntoHour(), .second = ds.getSecondsIntoMinute() };
}


fn next_path_component(path: []const u8, index: *usize) ?[]const u8 {
    while (index.* < path.len) {
        while (index.* < path.len and std.fs.path.isSep(path[index.*])) index.* = index.* + 1;
        const start = index.*;
        while (index.* < path.len and !std.fs.path.isSep(path[index.*])) index.* = index.* + 1;
        const part = path[start .. index.*];
        if (part.len == 0 or std.mem.eql(u8, part, ".")) continue;
        return part;
    }
    return null;
}


fn web_option_from_name(name: []const u8) ?class.WebOption {
    inline for (std.meta.fields(class.WebOption)) |field| {
        const option_name = if (std.mem.startsWith(u8, field.name, "status_")) field.name[7 .. ] else field.name;
        if (std.mem.eql(u8, name, option_name)) return @enumFromInt(field.value);
    }
    return null;
}


fn parse_button_flags(value: []const u8, state: *class.AppState) bool {
    if (std.mem.trim(u8, value, " \t").len == 0) return false;

    var flags = std.mem.splitScalar(u8, value, ',');
    while (flags.next()) |raw_flag| {
        const flag = std.mem.trim(u8, raw_flag, " \t");
        if (web_option_from_name(flag) == null) return false;
    }

    state.set_all_web_options(false);

    flags = std.mem.splitScalar(u8, value, ',');
    while (flags.next()) |raw_flag| {
        const flag = std.mem.trim(u8, raw_flag, " \t");
        state.set_status_for(web_option_from_name(flag).?, true);
    }
    return true;
}
