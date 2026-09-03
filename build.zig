const std = @import("std");


pub fn build(b: *std.Build) void {
    b.graph.incremental = false;

    const diagnostic = b.option(bool, "diagnostic", "Build with debug symbols and frame pointers") orelse false;
    const sanitize_thread = b.option(bool, "sanitize-thread", "Enable ThreadSanitizer (Linux native only)") orelse false;
    const name = b.option([]const u8, "name", "Executable name") orelse "ziger";
    const optimize: std.builtin.OptimizeMode = if (diagnostic or sanitize_thread) .Debug else .ReleaseSmall;

    const target = b.standardTargetOptions(
        .{
            .default_target = .{ .cpu_model = .native },
            .whitelist = null
        }
    );

    const mod = b.createModule(
        .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = !diagnostic and !sanitize_thread,
            .unwind_tables = if (diagnostic or sanitize_thread) .sync else .none,
            .error_tracing = diagnostic or sanitize_thread,
            .stack_protector = false,
            .stack_check = diagnostic or sanitize_thread,
            .omit_frame_pointer = !diagnostic and !sanitize_thread,
            .sanitize_c = if (diagnostic) .full else .off,
            .sanitize_thread = sanitize_thread,
            .fuzz = false,
            .single_threaded = false,
            .link_libc = true
        }
    );

    mod.addImport(
        "httpz",
        b.dependency(
            "httpz",
            .{
                .target = target,
                .optimize = optimize,
                .tsan = sanitize_thread
            }
        ).module("httpz")
    );

    if (target.result.os.tag == .windows) {
        mod.linkSystemLibrary("iphlpapi", .{});
        mod.linkSystemLibrary("ws2_32", .{});
    }

    const exe = b.addExecutable(
        .{
            .name = name,
            .root_module = mod
        }
    );

    exe.link_function_sections = true;
    exe.link_data_sections = true;
    exe.link_gc_sections = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the ziger app server");

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);
}
