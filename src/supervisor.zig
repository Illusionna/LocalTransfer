const std = @import("std");
const builtin = @import("builtin");
const class = @import("class.zig");
const utils = @import("utils.zig");


extern "kernel32" fn FindFirstChangeNotificationW(path: [*:0]const u16, watch_subtree: i32, filter: u32) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn FindNextChangeNotification(handle: *anyopaque) callconv(.winapi) i32;
extern "kernel32" fn FindCloseChangeNotification(handle: *anyopaque) callconv(.winapi) i32;
extern "kernel32" fn WaitForSingleObject(handle: *anyopaque, milliseconds: u32) callconv(.winapi) u32;


pub fn monitor(io: std.Io, allocator: std.mem.Allocator, hub: *class.WatchHub, share_dir: []const u8) void {
    const root = std.fs.path.resolve(allocator, &.{ share_dir }) catch |err| {
        std.log.err("cannot resolve shared directory: {s}", .{ @errorName(err) });
        return;
    };
    defer allocator.free(root);
    var previous = utils.dir_hash(io, allocator, root) catch |err| {
        std.log.err("cannot hash shared directory: {s}", .{ @errorName(err) });
        return;
    };
    const context = class.MonitorContext{ .io = io, .allocator = allocator, .hub = hub, .root = root, .previous_hash = &previous };
    switch (builtin.os.tag) {
        .linux => monitor_linux(context) catch |err| std.log.err("inotify supervisor failed: {s}", .{ @errorName(err) }),
        .macos => monitor_macos(context) catch |err| std.log.err("FSEvents supervisor failed: {s}", .{ @errorName(err) }),
        .windows => monitor_windows(context) catch |err| std.log.err("Windows supervisor failed: {s}", .{ @errorName(err) }),
        else => @compileError("supervisor supports Linux, macOS, and Windows")
    }
}


fn refresh_after_native_change(context: class.MonitorContext) void {
    std.Io.sleep(context.io, class.settle_time, .awake) catch {};
    if (!context.hub.is_stopping(context.io)) broadcast_if_directory_changed(context);
}


fn broadcast_if_directory_changed(context: class.MonitorContext) void {
    const current_hash = utils.dir_hash(context.io, context.allocator, context.root) catch |err| {
        std.log.warn("cannot hash shared directory: {s}", .{@errorName(err)});
        return;
    };
    if (current_hash == context.previous_hash.*) return;
    context.previous_hash.* = current_hash;
    context.hub.broadcast(context.io, context.allocator, class.changed_message);
}


fn monitor_linux(context: class.MonitorContext) !void {
    const fd = std.c.inotify_init1(class.LinuxWatch.init_nonblock | class.LinuxWatch.init_cloexec);
    if (fd < 0) return error.InotifyInitFailed;
    defer _ = std.c.close(fd);
    try add_linux_watches(context, fd, class.LinuxWatch.event_mask);
    var events: [16 * 1024]u8 = undefined;
    while (!context.hub.is_stopping(context.io)) {
        var fds = [_]std.posix.pollfd{.{ .fd = fd, .events = std.posix.POLL.IN, .revents = 0 }};
        _ = std.posix.poll(&fds, class.shutdown_poll_ms) catch continue;
        if (fds[0].revents == 0) continue;
        _ = std.posix.read(fd, &events) catch continue;
        try add_linux_watches(context, fd, class.LinuxWatch.event_mask);
        refresh_after_native_change(context);
    }
}


fn add_linux_watches(context: class.MonitorContext, fd: std.posix.fd_t, mask: u32) !void {
    var directory = try std.Io.Dir.cwd().openDir(context.io, context.root, .{ .iterate = true });
    defer directory.close(context.io);
    try add_linux_watch(context.allocator, fd, context.root, mask);
    var walker = try directory.walk(context.allocator);
    defer walker.deinit();
    while (try walker.next(context.io)) |entry| {
        if (entry.kind != .directory) continue;
        const path = try std.fs.path.join(context.allocator, &.{ context.root, entry.path });
        defer context.allocator.free(path);
        try add_linux_watch(context.allocator, fd, path, mask);
    }
}


fn add_linux_watch(allocator: std.mem.Allocator, fd: std.posix.fd_t, path: []const u8, mask: u32) !void {
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);
    if (std.c.inotify_add_watch(fd, path_z, mask) < 0) return error.InotifyWatchFailed;
}


fn monitor_windows(context: class.MonitorContext) !void {
    const root_w = try std.unicode.wtf8ToWtf16LeAllocZ(context.allocator, context.root);
    defer context.allocator.free(root_w);
    const handle = FindFirstChangeNotificationW(root_w, 1, class.WindowsWatch.filter) orelse return error.WatchCreationFailed;
    if (@intFromPtr(handle) == std.math.maxInt(usize)) return error.WatchCreationFailed;
    defer _ = FindCloseChangeNotification(handle);
    while (!context.hub.is_stopping(context.io)) {
        switch (WaitForSingleObject(handle, class.shutdown_poll_ms)) {
            class.WindowsWatch.wait_signaled => {
                if (FindNextChangeNotification(handle) == 0) return error.WatchRearmFailed;
                refresh_after_native_change(context);
            },
            class.WindowsWatch.wait_timeout => {},
            else => return error.WatchWaitFailed
        }
    }
}


fn monitor_macos(context: class.MonitorContext) !void {
    const dispatch = std.c.dispatch;
    var framework = try std.DynLib.open("/System/Library/Frameworks/CoreServices.framework/CoreServices");
    defer framework.close();
    var api: class.MacApi = undefined;
    inline for (@typeInfo(class.MacApi).@"struct".fields) |field| {
        @field(api, field.name) = framework.lookup(field.type, field.name) orelse return error.MissingCoreServicesSymbol;
    }
    const root_z = try context.allocator.dupeZ(u8, context.root);
    defer context.allocator.free(root_z);
    const queue = dispatch.queue_create("local-transfer-supervisor", .SERIAL()) orelse return error.SystemResources;
    defer queue.as_object().release();
    const semaphore = dispatch.semaphore_create(0) orelse return error.SystemResources;
    defer semaphore.as_object().release();
    const cf_path = api.CFStringCreateWithCString(null, root_z, class.cf_string_utf8) orelse return error.InvalidWatchPath;
    defer api.CFRelease(cf_path);
    const values = [_]usize{@intFromPtr(cf_path)};
    const paths = api.CFArrayCreate(null, &values, values.len, null) orelse return error.SystemResources;
    defer api.CFRelease(paths);
    const stream = api.FSEventStreamCreate(null, mac_event, &.{ .version = 0, .info = semaphore }, paths, std.math.maxInt(u64), 0.1, .{ .file_events = true }) orelse return error.StreamCreationFailed;
    defer api.FSEventStreamRelease(stream);
    api.FSEventStreamSetDispatchQueue(stream, queue);
    defer api.FSEventStreamInvalidate(stream);
    if (!api.FSEventStreamStart(stream)) return error.StreamStartFailed;
    defer api.FSEventStreamStop(stream);
    while (!context.hub.is_stopping(context.io)) {
        if (semaphore.wait(.time(.NOW, class.shutdown_poll_ms * std.time.ns_per_ms)) != 0) continue;
        refresh_after_native_change(context);
    }
}


fn mac_event(_: *const anyopaque, context: ?*anyopaque, _: usize, _: *anyopaque, _: [*]const u32, _: [*]const u64) callconv(.c) void {
    const semaphore: std.c.dispatch.semaphore_t = @ptrCast(@alignCast(context));
    _ = semaphore.signal();
}
