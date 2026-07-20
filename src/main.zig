const std = @import("std");
const httpz = @import("httpz");
const core = @import("core.zig");
const class = @import("class.zig");
const usage = @import("usage.zig");
const utils = @import("utils.zig");
const controllers = @import("controllers.zig");


pub const std_options: std.Options = .{
    .log_level = .warn,
    .log_scope_levels = &.{
        .{
            .scope = .websocket,
            .level = .warn
        }
    }
};


pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var cfg = class.AppConfig.init(gpa);
    defer cfg.deinit(gpa);

    var state: class.AppState = .{};
    defer state.deinit(gpa);
    var hub: class.WatchHub = .{};
    defer hub.deinit(gpa);

    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer args_iter.deinit();
    var args_list: std.ArrayList([:0]const u8) = .empty;
    defer args_list.deinit(gpa);

    while (args_iter.next()) |x| try args_list.append(gpa, x);

    if (!utils.parse_flags(args_list.items, &cfg, &state)) {
        var buffer: [4096]u8 = undefined;
        var fw = std.Io.File.stderr().writer(init.io, &buffer);
        usage.print_usage(&fw.interface, &cfg, args_list.items[0]) catch {};
        fw.interface.flush() catch {};
        return;
    }

    const port = std.fmt.parseInt(u16, cfg.host_port, 10) catch {
        var err_buffer: [4096]u8 = undefined;
        var err_fw = std.Io.File.stderr().writer(init.io, &err_buffer);
        try err_fw.interface.print("invalid --port value: {s}\n", .{ cfg.host_port });
        try err_fw.interface.flush();
        return;
    };
    const address = utils.listen_address(cfg.host_ipv4, port) catch {
        var err_buffer: [4096]u8 = undefined;
        var err_fw = std.Io.File.stderr().writer(init.io, &err_buffer);
        try err_fw.interface.print("invalid --ip value: {s}\n", .{ cfg.host_ipv4 });
        try err_fw.interface.flush();
        return;
    };

    var buffer: [4096]u8 = undefined;
    var fw = std.Io.File.stdout().writer(init.io, &buffer);
    try usage.print_launch(&fw.interface, &cfg, args_list.items[0]);
    try fw.interface.flush();

    var app = class.App{
        .cfg = &cfg,
        .hub = &hub,
        .gpa = gpa,
        .state = &state,
        .io = init.io
    };
    var handler = class.Handler{ .app = &app };

    const sigint_set = utils.block_sigint();

    var watcher = try std.Thread.spawn(
        .{},
        core.monitor,
        .{ init.io, gpa, &hub, cfg.share_dir, 1200 }
    );
    var watcher_running = true;
    defer {
        if (watcher_running) {
            hub.stop(init.io);
            watcher.join();
        }
    }

    var server = try httpz.Server(*class.Handler).init(
        init.io,
        gpa,
        .{
            .address = address,
            .workers = .{
                .count = 1,
                .min_conn = 8,
                .max_conn = 256,
                .large_buffer_count = 8,
                .large_buffer_size = 64 * 1024,
                .retain_allocated_bytes = 8 * 1024
            },
            .thread_pool = .{
                .count = 8,
                .backlog = 32,
                .buffer_size = 16 * 1024
            },
            .request = .{
                .max_body_size = utils.upload_request_limit(&cfg),
                .buffer_size = 8 * 1024,
                .lazy_read_size = 64 * 1024,
                .max_header_count = 32,
                .max_query_count = 16,
                .max_param_count = 8,
                .max_form_count = 8
            },
            .response = .{
                .max_header_count = 32
            },
            .timeout = .{
                .request = 15,
                .keepalive = 5,
                .request_count = 50
            }
        },
        &handler
    );

    defer server.deinit();

    var router = try server.router(.{});

    router.get("/login/", controllers.login_handler, .{});
    router.get("/", controllers.index_handler, .{});
    router.get("/UI/*", controllers.ui_handler, .{});
    router.get("/docs/", controllers.docs_handler, .{});
    router.get("/api/share/*", controllers.share_handler, .{});
    router.get("/api/file-list/", controllers.filelist_handler, .{});
    router.get("/api/watch/", controllers.watch_handler, .{});

    router.post("/login/", controllers.login_handler, .{});
    router.post("/api/file-property/", controllers.file_property_handler, .{});
    router.post("/api/edit-announcement/", controllers.edit_handler, .{});
    router.post("/api/announcement-content/", controllers.announcement_handler, .{});
    router.post("/api/upload-file/", controllers.upload_handler, .{});
    router.post("/api/search-file/", controllers.search_handler, .{});
    router.post("/api/delete-file/", controllers.delete_handler, .{});
    router.post("/api/batch-download/", controllers.batch_download_handler, .{});
    router.post("/api/make-directory/", controllers.makedir_handler, .{});
    router.post("/api/copy-file/", controllers.copy_file_handler, .{});
    router.post("/api/move-file/", controllers.move_file_handler, .{});
    router.post("/api/rename-file/", controllers.rename_handler, .{});

    const listen_thread = try server.listenInNewThread();

    utils.wait_for_sigint(init.io, &sigint_set);

    server.stop();
    hub.stop(init.io);
    watcher.join();
    watcher_running = false;
    listen_thread.join();

    try usage.print_shutdown(&fw.interface);
    try fw.interface.flush();
}