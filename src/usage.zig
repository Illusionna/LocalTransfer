const std = @import("std");
const builtin = @import("builtin");
const class = @import("class.zig");
const utils = @import("utils.zig");


pub fn print_logo(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        "\x1b[1;37m   _\x1b[0m\n" ++
        "\x1b[1;31m  ( \\                ..-----..__\x1b[0m\n" ++
        "\x1b[1;31m   \\.' .        _.--'`  [   '  ' ```'-._\x1b[0m\n" ++
        "\x1b[1;32m    `. `'-..-'' `    '  ' '   .  ;   ; `-'''-.,__/|/_\x1b[0m\n" ++
        "\x1b[1;32m      `'-.;..-''`|'  `.  '.    ;     '  `    '   `'  `,\x1b[0m\n" ++
        "\x1b[1;33m                 \\ '   .    ' .     '   ;   .`   . ' 7 \\\x1b[0m\n" ++
        "\x1b[1;33m                  '.' . '- . \\    .`   .`  .   .\\     `Y\x1b[0m\n" ++
        "\x1b[1;34m                    '-.' .   ].  '   ,    '    /'`\"\"';:'\x1b[0m\n" ++
        "\x1b[1;34m                      /Y   '.] '-._ /    ' _.-'\x1b[0m\n" ++
        "\x1b[1;35m                      \\'\\_   ; (`'.'.'  .\"/\"\x1b[0m\n" ++
        "\x1b[1;35m                       ' )` /  `.'   .-'.'\x1b[0m\n" ++
        "\x1b[1;36m                        '\\  \\).'  .-'--\"\x1b[0m\n" ++
        "\x1b[1;36m                          `. `,_'`\x1b[0m\n" ++
        "\x1b[1;37m                            `.__)\x1b[0m\n\n"
    );
}


pub fn print_launch(writer: *std.Io.Writer, cfg: *const class.AppConfig, argv0: []const u8) !void {
    var buffer: [64]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buffer);
    utils.write_file_size(&fbs, cfg.max_bytes()) catch {};
    try print_logo(writer);
    try writer.print("* \x1b[1;32mINFO\x1b[0m: Started server process ID [\x1b[1;36m{d}\x1b[0m]\n", .{ process_id() });
    try writer.print("* \x1b[1;32mINFO\x1b[0m: Shared file directory: \x1b[1;36m\"{s}\"\x1b[0m\n", .{ cfg.share_dir });
    try writer.print("* \x1b[1;32mINFO\x1b[0m: Saved file directory: \x1b[1;36m\"{s}\"\x1b[0m\n", .{ cfg.store_dir });
    try writer.print("* \x1b[1;32mINFO\x1b[0m: Login password: \x1b[38;2;255;165;0m\"{s}\"\x1b[0m\n", .{ cfg.login_pwd });
    try writer.print("* \x1b[1;32mINFO\x1b[0m: Limit maximum file size: \x1b[1;36m{s}\x1b[0m\n", .{ fbs.buffered() });
    try writer.print("* \x1b[1;32mINFO\x1b[0m: See help document >>> \x1b[1;36m{s} --help\x1b[0m\n", .{ argv0 });
    try writer.print("* \x1b[1;32mINFO\x1b[0m: Zig HTTP service is running on \x1b[1;36mhttp://{s}:{s}\x1b[0m (Press \x1b[1;33mCTRL+C\x1b[0m to quit)\n", .{ cfg.host_ipv4, cfg.host_port });
}


pub fn print_shutdown(writer: *std.Io.Writer) !void {
    try writer.print("\n* \x1b[1;32mINFO\x1b[0m: Waiting for application shutdown.\n", .{});
    try writer.print("* \x1b[1;32mINFO\x1b[0m: Finished server process ID [\x1b[1;36m{d}\x1b[0m]\n", .{ process_id() });
}


pub fn print_usage(writer: *std.Io.Writer, cfg: *const class.AppConfig, argv0: []const u8) !void {
    try writer.writeAll(
        "      _                 \n" ++
        "  ___(_) __ _  ___ _ __   Zig Local Transfer (MIT License)\n" ++
        " |_  / |/ _` |/ _ \\ '__|  available version V6 (built with Zig 0.16.0)\n" ++
        "  / /| | (_| |  __/ |     https://github.com/Illusionna/LocalTransfer\n" ++
        " /___|_|\\__, |\\___|_|     Illusionna (Zolio Marling) www@orzzz.net\n" ++
        "        |___/\n"
    );
    try writer.print("Usage\n", .{});
    try writer.print("    >>> \x1b[1;36m{s} --share \"./Desktop/project\" --button \"upload, search, mkdir\" --max \"36 MB\"\x1b[0m\n", .{ argv0 });
    try writer.print("\nDescription\n", .{});
    try writer.print("    \x1b[1;32m--share -share\x1b[0m (string)\n\tShared file directory (default: \x1b[1;36m\"{s}\"\x1b[0m)\n\n",  .{ cfg.share_dir });
    try writer.print("    \x1b[1;32m--store -store\x1b[0m (string)\n\tUploaded file storage directory (default: \x1b[1;36m\"{s}\"\x1b[0m)\n\n",  .{ cfg.store_dir });
    try writer.print("    \x1b[1;32m--ip -ip\x1b[0m (string)\n\tServer IPv4 address (default: \x1b[1;36m\"{s}\"\x1b[0m)\n\n",  .{ cfg.host_ipv4 });
    try writer.print("    \x1b[1;32m--port -port\x1b[0m (string)\n\tServer listening port (default: \x1b[1;36m\"{s}\"\x1b[0m)\n\n",  .{ cfg.host_port });
    try writer.print("    \x1b[1;32m--max -max\x1b[0m (string)\n\tMaximum upload file size (default: \x1b[1;36m\"{s}\"\x1b[0m)\n\n",  .{ cfg.limit_max });
    try writer.print("    \x1b[1;32m--login -login\x1b[0m (string)\n\tLogin password (default: \x1b[1;36m\"{s}\"\x1b[0m)\n\n",  .{ cfg.login_pwd });
    try writer.print("    \x1b[1;32m--button -button\x1b[0m (string)\n\tEnable only the listed web options\n\t(default: \x1b[1;36m\"announcement, upload, search, delete, mkdir, copy, move, rename\"\x1b[0m)\n",  .{});
}


fn process_id() u64 {
    if (comptime builtin.os.tag == .windows) return std.os.windows.GetCurrentProcessId();
    return @intCast(std.c.getpid());
}