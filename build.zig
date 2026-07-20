const std = @import("std");


pub fn build(b: *std.Build) void {
    b.graph.incremental = false;

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
            .optimize = .ReleaseSmall,
            .strip = true,
            .unwind_tables = .none,
            .error_tracing = false,
            .stack_protector = false,
            .stack_check = false,
            .omit_frame_pointer = true,
            .sanitize_c = .off,
            .sanitize_thread = false,
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
                .optimize = .ReleaseFast
            }
        ).module("httpz")
    );

    if (target.result.os.tag == .windows) {
        mod.linkSystemLibrary("iphlpapi", .{});
        mod.linkSystemLibrary("ws2_32", .{});
    }

    const exe = b.addExecutable(
        .{
            .name = "ziger",
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