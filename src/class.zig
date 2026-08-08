const std = @import("std");
const httpz = @import("httpz");
const builtin = @import("builtin");
const utils = @import("utils.zig");


pub const changed_message = "{\"type\": \"changed\"}";
pub const settle_time = std.Io.Duration.fromMilliseconds(500);
pub const shutdown_poll_ms = 1000;
pub const cf_string_utf8 = 0x0800_0100;


pub const search_max_roots = 32;
pub const search_max_depth = 16;
pub const search_max_files = 5_000;
pub const search_max_results = 512;
pub const search_default_page_size = 64;
pub const search_max_duration_ms = 12_000;
pub const search_max_file_read_bytes = 256 * 1024;


pub const LinuxWatch = struct {
    pub const init_nonblock = 0x800;
    pub const init_cloexec = 0x80000;
    pub const event_mask = 0x0000_0fce;
};


pub const WindowsWatch = struct {
    const filter = 0x0000_001f;
    const wait_signaled = 0;
    const wait_timeout = 0x0000_0102;
};


pub const MonitorContext = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    hub: *WatchHub,
    root: []const u8,
    previous_hash: *u64
};


const FSEventStreamContext = extern struct {
    version: isize,
    info: ?*anyopaque,
    retain: ?*const anyopaque = null,
    release: ?*const anyopaque = null,
    copy_description: ?*const anyopaque = null,
};


const FSEventStreamCreateFlags = packed struct(u32) {
    use_cf_types: bool = false,
    no_defer: bool = false,
    watch_root: bool = false,
    ignore_self: bool = false,
    file_events: bool = false,
    _: u27 = 0,
};


pub const MacApi = struct {
    FSEventStreamCreate: *const fn (
        ?*const anyopaque,
        *const fn (
            *const anyopaque,
            ?*anyopaque,
            usize,
            *anyopaque,
            [*]const u32,
            [*]const u64
        ) callconv(.c) void,
        ?*const FSEventStreamContext,
        *const anyopaque,
        u64,
        f64,
        FSEventStreamCreateFlags
    ) callconv(.c) ?*anyopaque,
    FSEventStreamSetDispatchQueue: *const fn (*anyopaque, std.c.dispatch.queue_t) callconv(.c) void,
    FSEventStreamStart: *const fn (*anyopaque) callconv(.c) bool,
    FSEventStreamStop: *const fn (*anyopaque) callconv(.c) void,
    FSEventStreamInvalidate: *const fn (*anyopaque) callconv(.c) void,
    FSEventStreamRelease: *const fn (*anyopaque) callconv(.c) void,
    CFRelease: *const fn (*const anyopaque) callconv(.c) void,
    CFArrayCreate: *const fn (
        ?*const anyopaque,
        [*]const usize,
        isize,
        ?*const anyopaque
    ) callconv(.c) ?*const anyopaque,
    CFStringCreateWithCString: *const fn (?*const anyopaque, [*:0]const u8, u32) callconv(.c) ?*const anyopaque
};


pub const SearchBudget = struct {
    started: std.Io.Timestamp,
    scanned_files: usize = 0,
    truncated: bool = false,

    pub fn exhausted(self: *SearchBudget, io: std.Io) bool {
        if (self.scanned_files >= search_max_files) {
            self.truncated = true;
            return true;
        }
        if (self.started.untilNow(io, .awake).toMilliseconds() >= search_max_duration_ms) {
            self.truncated = true;
            return true;
        }
        return false;
    }
};


pub const SigintSet = if (builtin.os.tag == .windows) void else std.posix.sigset_t;


pub const WindowsSigint = if (builtin.os.tag == .windows) struct {
    const ConsoleHandler = *const fn (control_type: std.os.windows.DWORD) callconv(.winapi) std.os.windows.BOOL;
    pub extern "kernel32" fn SetConsoleCtrlHandler(handler: ?ConsoleHandler, add: std.os.windows.BOOL) callconv(.winapi) std.os.windows.BOOL;

    const CTRL_C_EVENT: std.os.windows.DWORD = 0;
    const CTRL_BREAK_EVENT: std.os.windows.DWORD = 1;
    pub var received = std.atomic.Value(bool).init(false);

    pub fn console(control_type: std.os.windows.DWORD) callconv(.winapi) std.os.windows.BOOL {
        if (control_type == CTRL_C_EVENT or control_type == CTRL_BREAK_EVENT) {
            received.store(true, .release);
            return std.os.windows.BOOL.TRUE;
        }
        return .FALSE;
    }
} else struct {};


pub const TransferMode = enum {
    transfer_copy,
    transfer_move
};


pub const WebOption = enum {
    status_announcement,
    status_upload,
    status_search,
    status_delete,
    status_mkdir,
    status_copy,
    status_move,
    status_rename 
};


const ZipState = enum {
    status_writing,
    status_finished,
    status_failed
};


const BoundaryMatch = union(enum) {
    found: usize,
    preserve: usize,
    none
};


const Entry = struct {
    name: []u8,
    crc: u32,
    size: u64,
    offset: u64,
    is_directory: bool,
};


pub const UI = struct {
    path: []const u8,
    file: []const u8,
};


pub const App = struct {
    cfg: *AppConfig,
    hub: *WatchHub,
    gpa: std.mem.Allocator,
    state: *AppState,
    io: std.Io,
};


pub const StdTimeFormat = struct {
    year: u12,
    month: u4,
    day: u5,
    hour: u5,
    minute: u6,
    second: u6,
};


pub const ChineseTime = struct {
    interval: i64,
    label: []const u8,
};


pub const FileInfo = struct {
    FileName: []const u8,
    FileSize: []const u8,
    FileIcon: []const u8,
    ModifiedTime: []const u8,
};


pub const FileRequest = struct {
    Path: []const u8 = "",
    CurrentDir: []const u8 = "",
};


pub const FileProperty = struct {
    FileCount: i64,
    SumSize: []const u8,
    ModifiedTime: []const u8,
    AgoTime: []const u8,
};


pub const FileSearch = struct {
    Path: []const []const u8 = &.{},
    Target: []const u8 = "",
    CurrentDir: []const u8 = "",
    Offset: usize = 0,
    Limit: usize = 0,
};


pub const FileRename = struct {
    CurrentDir: []const u8 = "",
    OldName: []const u8 = "",
    NewName: []const u8 = "",
    Prefix: []const u8 = "",
    Suffix: []const u8 = "",
};


pub const RenamePlan = struct {
    source: []u8,
    destination: []u8,
    temporary: []u8,
    display: []const u8,
    is_directory: bool,
    state: enum { pending, staged, committed, unchanged } = .pending,
};


pub const FileOperationResult = struct {
    Path: []const u8,
    Success: bool,
    Error: []const u8 = "",
};


pub const SearchResult = struct {
    Path: []const u8,
    Description: []const u8 = "",
};


pub const SearchResponse = struct {
    Results: []const SearchResult,
    NextOffset: ?usize = null,
    Truncated: bool = false,
    ScannedFiles: usize = 0,
};


pub const FileSizeCount = struct {
    size: i64,
    count: i64,
};


pub const ContentPresentation = struct {
    content_type: []const u8,
    should_inline: bool,
};


pub const Listener = struct {
    id: u64,
    ctx: *anyopaque,
    callback: *const fn (*anyopaque, []const u8) anyerror!void,
    active_callbacks: usize = 0,
    removing: bool = false,
};


pub const WatchContext = struct {
    io: std.Io,
    gpa: std.mem.Allocator,
    hub: *WatchHub,
};


pub const ConfinedParent = struct {
    dir: std.Io.Dir,
    leaf: []const u8,

    pub fn close(self: *ConfinedParent, io: std.Io) void {
        self.dir.close(io);
    }
};


pub const ChunkReader = struct {
    ctx: *anyopaque,
    callback: *const fn (ctx: *anyopaque, dst: []u8) anyerror!usize,

    fn read(self: ChunkReader, dst: []u8) anyerror!usize {
        return self.callback(self.ctx, dst);
    }
};


pub const AppConfig = struct {
    host_ipv4: []const u8 = "localhost",
    host_port: []const u8 = "8888",
    share_dir: []const u8 = ".",
    store_dir: []const u8 = ".",
    limit_max: []const u8 = "1.2 GB",
    login_pwd: []const u8 = "",
    memory_allocated_host_ipv4: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator) AppConfig {
        var self: AppConfig = .{};
        self.memory_allocated_host_ipv4 = local_ipv4(allocator) catch return self;
        self.host_ipv4 = self.memory_allocated_host_ipv4.?;
        return self;
    }

    pub fn deinit(self: *AppConfig, allocator: std.mem.Allocator) void {
        if (self.memory_allocated_host_ipv4) |ip| {
            allocator.free(ip);
            self.memory_allocated_host_ipv4 = null;
        }
    }

    pub fn max_bytes(self: *const AppConfig) i64 {
        const default: i64 = 1288490188;
        const trimmed = std.mem.trim(u8, self.limit_max, " \t");
        if (trimmed.len == 0) return default;

        var i: usize = 0;
        while (i < trimmed.len) : (i = i + 1) if (!(std.ascii.isDigit(trimmed[i]) or trimmed[i] == '.')) break;

        const number = trimmed[0 .. i];
        var unit = std.mem.trim(u8, trimmed[i .. ], " \t");
        if (number.len == 0) return default;
        const value = std.fmt.parseFloat(f64, number) catch return default;

        var buffer: [4]u8 = undefined;
        if (unit.len > buffer.len) return default;
        for (unit, 0 .. ) |c, j| buffer[j] = std.ascii.toUpper(c);
        unit = buffer[0 .. unit.len];

        const multiplier: f64 = if (std.mem.eql(u8, unit, "B")) 1.0 else if (std.mem.eql(u8, unit, "KB")) 1024.0 else if (std.mem.eql(u8, unit, "MB")) 1024.0 * 1024.0 else if (std.mem.eql(u8, unit, "GB")) 1024.0 * 1024.0 * 1024.0 else if (std.mem.eql(u8, unit, "TB")) 1024.0 * 1024.0 * 1024.0 * 1024.0 else return default;
        return @intFromFloat(value * multiplier);
    }

    fn local_ipv4(allocator: std.mem.Allocator) ![]u8 {
        const os = @import("builtin").os.tag;
        var best: ?[4]u8 = null;
        var best_score: u8 = 0;

        if (comptime os == .macos or os == .linux) {
            const c = @cImport({
                @cInclude("ifaddrs.h");
                @cInclude("net/if.h");
                @cInclude("netinet/in.h");
            });
            const excluded = [_][]const u8{ "utun", "tun", "tap", "wg", "ppp", "ipsec", "awdl", "llw", "bridge", "br-", "docker", "veth", "virbr", "vmnet", "vboxnet", "tailscale", "zerotier" };

            var interfaces: ?*c.struct_ifaddrs = null;
            if (c.getifaddrs(&interfaces) != 0) return error.InterfaceEnumerationFailed;
            defer c.freeifaddrs(interfaces);
            var current = interfaces;

            scan: while (current) |item| : (current = item.*.ifa_next) {
                const required_flags = c.IFF_UP | c.IFF_RUNNING;
                if (item.*.ifa_flags & required_flags != required_flags or item.*.ifa_flags & c.IFF_LOOPBACK != 0) continue;
                const address = item.*.ifa_addr orelse continue;
                if (address.*.sa_family != c.AF_INET) continue;

                const name = std.mem.span(item.*.ifa_name);
                for (excluded) |prefix| {
                    if (std.mem.startsWith(u8, name, prefix)) continue :scan;
                }

                const ipv4: *const c.struct_sockaddr_in = @ptrCast(@alignCast(address));
                const bytes: *const [4]u8 = @ptrCast(&ipv4.*.sin_addr);
                if (bytes[0] == 0 or bytes[0] == 127 or (bytes[0] == 169 and bytes[1] == 254)) continue;

                const score: u8 = if (os == .macos and std.mem.eql(u8, name, "en0")) 40 else if (os == .macos and std.mem.startsWith(u8, name, "en")) 30 else if (os == .linux and (std.mem.startsWith(u8, name, "wl") or std.mem.startsWith(u8, name, "wlan"))) 30 else if (os == .linux and (std.mem.startsWith(u8, name, "eth") or std.mem.startsWith(u8, name, "en"))) 20 else 10;

                if (score > best_score) {
                    best_score = score;
                    best = bytes.*;
                }
            }
        }
        else if (comptime os == .windows) {
            const c = @cImport({
                @cDefine("_WIN32_WINNT", "0x0501");
                @cInclude("winsock2.h");
                @cInclude("iphlpapi.h");
                @cInclude("iptypes.h");
            });
            const flags = c.GAA_FLAG_SKIP_ANYCAST | c.GAA_FLAG_SKIP_MULTICAST | c.GAA_FLAG_SKIP_DNS_SERVER;
            const virtual_adapter_words = [_][]const u8{ "tap", "tun", "wireguard", "wintun", "openvpn", "hyper-v", "tailscale", "zerotier", "virtualbox", "vmware", "docker" };
            var buffer_size: c.ULONG = 0;
            if (c.GetAdaptersAddresses(c.AF_INET, flags, null, null, &buffer_size) != c.ERROR_BUFFER_OVERFLOW) return error.InterfaceEnumerationFailed;

            const buffer = try allocator.alignedAlloc(
                u8,
                .of(c.IP_ADAPTER_ADDRESSES),
                buffer_size,
            );
            defer allocator.free(buffer);

            const first: *c.IP_ADAPTER_ADDRESSES = @ptrCast(buffer.ptr);
            if (c.GetAdaptersAddresses(c.AF_INET, flags, null, first, &buffer_size) != c.NO_ERROR) return error.InterfaceEnumerationFailed;
            var adapter: ?*c.IP_ADAPTER_ADDRESSES = first;

            adapters: while (adapter) |item| : (adapter = item.*.Next) {
                if (item.*.OperStatus != c.IfOperStatusUp) continue;
                const score: u8 = switch (item.*.IfType) {
                    c.IF_TYPE_IEEE80211 => 30,
                    c.IF_TYPE_ETHERNET_CSMACD => 20,
                    else => continue,
                };

                if (score <= best_score) continue;

                for ([_]c.PWCHAR{ item.*.Description, item.*.FriendlyName }) |text| {
                    if (text == null) continue;
                    for (virtual_adapter_words) |word| {
                        var start: usize = 0;
                        while (text[start] != 0) : (start = start + 1) {
                            var i: usize = 0;
                            while (i < word.len and text[start + i] != 0) : (i = i + 1) {
                                const character = text[start + i];
                                if (character > 0x7f or std.ascii.toLower(@intCast(character)) != word[i]) break;
                            }
                            if (i == word.len) continue :adapters;
                        }
                    }
                }

                var unicast = item.*.FirstUnicastAddress;

                while (unicast) |candidate| : (unicast = candidate.*.Next) {
                    const address = candidate.*.Address.lpSockaddr orelse continue;
                    if (address.*.sa_family != c.AF_INET) continue;
                    const ipv4: *const c.struct_sockaddr_in = @ptrCast(@alignCast(address));
                    const bytes: *const [4]u8 = @ptrCast(&ipv4.*.sin_addr);
                    if (bytes[0] == 0 or bytes[0] == 127 or (bytes[0] == 169 and bytes[1] == 254)) continue;
                    best_score = score;
                    best = bytes.*;
                    break;
                }
            }
        }
        else {
            @compileError("Function local_ipv4() supports only macOS, Linux, and Windows.");
        }

        const bytes = best orelse return error.NoIpv4Address;
        return std.fmt.allocPrint(allocator, "{d}.{d}.{d}.{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });
    }
};


pub const AppState = struct {
    mutex: std.Io.Mutex = .init,
    file_mutex: std.Io.Mutex = .init,
    user_lock: std.StringHashMapUnmanaged(i64) = .empty,
    content_editable: std.ArrayList(u8) = .empty,
    status_announcement: bool = true,
    status_upload: bool = true,
    status_search: bool = true,
    status_delete: bool = true,
    status_mkdir: bool = true,
    status_copy: bool = true,
    status_move: bool = true,
    status_rename: bool = true,

    pub fn enable_status_for(self: *AppState, option: WebOption) bool {
        return switch (option) {
            .status_announcement => self.status_announcement,
            .status_upload => self.status_upload,
            .status_search => self.status_search,
            .status_delete => self.status_delete,
            .status_mkdir => self.status_mkdir,
            .status_copy => self.status_copy,
            .status_move => self.status_move,
            .status_rename => self.status_rename,
        };
    }

    pub fn set_status_for(self: *AppState, option: WebOption, enabled: bool) void {
        switch (option) {
            .status_announcement => self.status_announcement = enabled,
            .status_upload => self.status_upload = enabled,
            .status_search => self.status_search = enabled,
            .status_delete => self.status_delete = enabled,
            .status_mkdir => self.status_mkdir = enabled,
            .status_copy => self.status_copy = enabled,
            .status_move => self.status_move = enabled,
            .status_rename => self.status_rename = enabled,
        }
    }

    pub fn set_all_web_options(self: *AppState, enabled: bool) void {
        for (std.enums.values(WebOption)) |option| {
            self.set_status_for(option, enabled);
        }
    }

    pub fn deinit(self: *AppState, allocator: std.mem.Allocator) void {
        var keys = self.user_lock.keyIterator();
        while (keys.next()) |key| allocator.free(key.*);
        self.user_lock.deinit(allocator);
        self.content_editable.deinit(allocator);
    }
};


pub const WatchHub = struct {
    mutex: std.Io.Mutex = .init,
    idle: std.Io.Condition = .init,
    id: u64 = 0,
    listeners: std.ArrayList(Listener) = .empty,
    stopping: bool = false,

    pub fn subscribe(self: *WatchHub, io: std.Io, gpa: std.mem.Allocator, ctx: *anyopaque, callback: *const fn (*anyopaque, []const u8) anyerror!void) !u64 {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        const id = self.id;
        self.id = self.id + 1;
        try self.listeners.append(gpa, .{ .id = id, .ctx = ctx, .callback = callback });
        return id;
    }

    pub fn unsubscribe(self: *WatchHub, io: std.Io, id: u64) void {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        for (self.listeners.items, 0 .. ) |listener, i| if (listener.id == id) {
            self.listeners.items[i].removing = true;
            while (self.listeners.items[i].active_callbacks != 0) self.idle.waitUncancelable(io, &self.mutex);
            _ = self.listeners.swapRemove(i);
            return;
        };
    }

    pub fn broadcast(self: *WatchHub, io: std.Io, allocator: std.mem.Allocator, msg: []const u8) void {
        self.mutex.lockUncancelable(io);
        var ids = std.ArrayList(u64).initCapacity(allocator, self.listeners.items.len) catch {
            self.mutex.unlock(io);
            return;
        };
        defer ids.deinit(allocator);
        for (self.listeners.items) |listener| ids.appendAssumeCapacity(listener.id);
        self.mutex.unlock(io);

        for (ids.items) |id| {
            self.mutex.lockUncancelable(io);
            const index = self.listener_index(id) orelse {
                self.mutex.unlock(io);
                continue;
            };
            if (self.listeners.items[index].removing) {
                self.mutex.unlock(io);
                continue;
            }
            self.listeners.items[index].active_callbacks += 1;
            const listener = self.listeners.items[index];
            self.mutex.unlock(io);

            const failed = blk: {
                listener.callback(listener.ctx, msg) catch break :blk true;
                break :blk false;
            };

            self.mutex.lockUncancelable(io);
            const current_index = self.listener_index(id) orelse unreachable;
            const current = &self.listeners.items[current_index];
            current.active_callbacks -= 1;
            if (current.active_callbacks == 0) self.idle.broadcast(io);
            if (failed and !current.removing) _ = self.listeners.swapRemove(current_index);
            self.mutex.unlock(io);
        }
    }

    fn listener_index(self: *WatchHub, id: u64) ?usize {
        for (self.listeners.items, 0 .. ) |listener, i| if (listener.id == id) return i;
        return null;
    }

    pub fn stop(self: *WatchHub, io: std.Io) void {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        self.stopping = true;
    }

    pub fn is_stopping(self: *WatchHub, io: std.Io) bool {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        return self.stopping;
    }

    pub fn deinit(self: *WatchHub, allocator: std.mem.Allocator) void {
        self.listeners.deinit(allocator);
    }
};


pub const WatchClient = struct {
    mutex: std.Io.Mutex = .init,
    id: u64,
    io: std.Io,
    hub: *WatchHub,
    connect: *httpz.websocket.Conn,

    pub fn init(connect: *httpz.websocket.Conn, ctx: *const WatchContext) !WatchClient {
        return .{ .id = 0, .io = ctx.io, .hub = ctx.hub, .connect = connect };
    }

    pub fn afterInit(self: *WatchClient, ctx: *const WatchContext) !void {
        self.id = try self.hub.subscribe(self.io, ctx.gpa, @ptrCast(self), push_message);
        try self.connect.write("{\"type\": \"Hello World!\"}");
    }

    pub fn close(self: *WatchClient) void {
        self.hub.unsubscribe(self.io, self.id);
    }

    pub fn clientMessage(_: *WatchClient, _: []const u8) !void {
        // ignore.
    }

    fn push_message(ctx: *anyopaque, msg: []const u8) anyerror!void {
        const self: *WatchClient = @ptrCast(@alignCast(ctx));
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        try self.connect.write(msg);
    }
};


pub const Handler = struct {
    app: *App,
    pub const WebsocketHandler = WatchClient;

    pub fn notFound(_: *Handler, _: *httpz.Request, response: *httpz.Response) !void {
        response.status = 404;
        response.body = "[HTTP 404] not found";
    }

    pub fn uncaughtError(_: *Handler, request: *httpz.Request, response: *httpz.Response, err: anyerror) void {
        response.status = 500;
        response.body = "[HTTP 500] internal server error";
        response.header("error", std.fmt.allocPrint(response.arena, "[error] {s} -> {s}", .{ request.url.path, @errorName(err) }) catch "[error] failed to format error");
        response.header("state", "500");
    }
};


pub const SlidingWindowMultipartStreamParser = struct {
    buffer: []u8,
    reader: ChunkReader,
    length: usize = 0,
    eof: bool = false,

    pub fn fill_at_least(self: *SlidingWindowMultipartStreamParser, want: usize) ![]const u8 {
        if (want > self.buffer.len) return error.StreamParserBufferTooSmall;
        while (self.length < want and !self.eof) {
            const n = try self.reader.read(self.buffer[self.length .. ]);
            if (n == 0) {
                self.eof = true;
                break;
            }
            self.length = self.length + n;
        }
        if (self.length < want) return error.EndOfStream;
        return self.buffer[0 .. self.length];
    }

    pub fn advance(self: *SlidingWindowMultipartStreamParser, k: usize) void {
        std.debug.assert(k <= self.length);
        const remain = self.length - k;
        std.mem.copyForwards(u8, self.buffer[0 .. remain], self.buffer[k .. self.length]);
        self.length = remain;
    }

    pub fn skip_until_boundary(self: *SlidingWindowMultipartStreamParser, needle: []const u8) !void {
        try self.validate_boundary_needle(needle);
        while (true) {
            _ = try self.fill_for_search(needle.len, error.NoBoundary);
            switch (try self.find_boundary_needle(needle)) {
                .found => |p| {
                    self.advance(p + needle.len);
                    return;
                },
                .preserve => |p| {
                    if (p > 0) self.advance(p);
                },
                .none => {
                    self.advance(self.flushable_prefix_len(needle));
                    if (self.eof) return error.NoBoundary;
                },
            }
        }
    }

    pub fn stream_until_boundary(self: *SlidingWindowMultipartStreamParser, w: *std.Io.Writer, needle: []const u8, max_size: usize) !void {
        try self.validate_boundary_needle(needle);
        var written: usize = 0;
        while (true) {
            _ = try self.fill_for_search(needle.len, error.UnexpectedEof);
            switch (try self.find_boundary_needle(needle)) {
                .found => |p| {
                    if (p > max_size - written) return error.FileTooLarge;
                    try self.write_prefix(w, p);
                    written = written + p;
                    self.advance(needle.len);
                    return;
                },
                .preserve => |p| {
                    if (p > max_size - written) return error.FileTooLarge;
                    try self.write_prefix(w, p);
                    written = written + p;
                },
                .none => {
                    const count = self.flushable_prefix_len(needle);
                    if (count > max_size - written) return error.FileTooLarge;
                    try self.write_prefix(w, count);
                    written = written + count;
                    if (self.eof) return error.UnexpectedEof;
                },
            }
        }
    }

    pub fn collect_until_boundary(self: *SlidingWindowMultipartStreamParser, needle: []const u8, dst: []u8) ![]u8 {
        try self.validate_boundary_needle(needle);
        var written: usize = 0;
        while (true) {
            _ = try self.fill_for_search(needle.len, error.UnexpectedEof);
            switch (try self.find_boundary_needle(needle)) {
                .found => |p| {
                    try self.collect_prefix(dst, &written, p, error.FormFieldTooLarge);
                    self.advance(needle.len);
                    return dst[0 .. written];
                },
                .preserve => |p| {
                    try self.collect_prefix(dst, &written, p, error.FormFieldTooLarge);
                },
                .none => {
                    try self.collect_prefix(dst, &written, self.flushable_prefix_len(needle), error.FormFieldTooLarge);
                    if (self.eof) return error.UnexpectedEof;
                },
            }
        }
    }

    pub fn collect_until_needle(self: *SlidingWindowMultipartStreamParser, needle: []const u8, dst: []u8) ![]u8 {
        try self.validate_needle(needle);
        var written: usize = 0;
        while (true) {
            const s = try self.fill_for_search(needle.len, error.UnexpectedEof);
            if (std.mem.indexOf(u8, s, needle)) |p| {
                try self.collect_prefix(dst, &written, p, error.HeadersTooLarge);
                self.advance(needle.len);
                return dst[0 .. written];
            }
            try self.collect_prefix(dst, &written, self.flushable_prefix_len(needle), error.HeadersTooLarge);
            if (self.eof) return error.UnexpectedEof;
        }
    }

    fn validate_needle(self: *const SlidingWindowMultipartStreamParser, needle: []const u8) !void {
        if (needle.len == 0) return error.InvalidNeedle;
        if (needle.len > self.buffer.len) return error.StreamParserBufferTooSmall;
    }

    fn validate_boundary_needle(self: *const SlidingWindowMultipartStreamParser, needle: []const u8) !void {
        try self.validate_needle(needle);
        if (self.buffer.len < 2 or needle.len > self.buffer.len - 2) return error.StreamParserBufferTooSmall;
    }

    fn boundary_suffix_valid(s: []const u8) bool {
        return std.mem.startsWith(u8, s, "\r\n") or std.mem.startsWith(u8, s, "--");
    }

    fn find_boundary_needle(self: *SlidingWindowMultipartStreamParser, needle: []const u8) !BoundaryMatch {
        var search_start: usize = 0;
        while (std.mem.indexOfPos(u8, self.buffer[0 .. self.length], search_start, needle)) |p| {
            const after = p + needle.len;
            const required = after + 2;
            if (self.length < required and !self.eof and required <= self.buffer.len) {
                _ = self.fill_at_least(required) catch |err| switch (err) {
                    error.EndOfStream => self.buffer[0 .. self.length],
                    else => return err,
                };
            }
            if (self.length >= required) {
                if (boundary_suffix_valid(self.buffer[after .. self.length])) return .{ .found = p };
                search_start = p + 1;
                continue;
            }
            if (self.eof) return .none;
            return .{ .preserve = p };
        }
        return .none;
    }

    fn fill_for_search(self: *SlidingWindowMultipartStreamParser, want: usize, end_error: anyerror) ![]const u8 {
        return self.fill_at_least(want) catch |err| switch (err) {
            error.EndOfStream => return end_error,
            else => return err,
        };
    }

    fn flushable_prefix_len(self: *const SlidingWindowMultipartStreamParser, needle: []const u8) usize {
        return self.length - (needle.len - 1);
    }

    fn write_prefix(self: *SlidingWindowMultipartStreamParser, w: *std.Io.Writer, count: usize) !void {
        if (count == 0) return;
        try w.writeAll(self.buffer[0 .. count]);
        self.advance(count);
    }

    fn collect_prefix(self: *SlidingWindowMultipartStreamParser, dst: []u8, written: *usize, count: usize, too_large: anyerror) !void {
        if (written.* + count > dst.len) return too_large;
        @memcpy(dst[written.* .. written.* + count], self.buffer[0 .. count]);
        written.* = written.* + count;
        self.advance(count);
    }
};


pub const ChunkingWriter = struct {
    response: *httpz.Response,
    interface: std.Io.Writer,

    pub fn init(response: *httpz.Response, buffer: []u8) ChunkingWriter {
        return .{ .response = response, .interface = .{ .buffer = buffer, .vtable = &.{ .drain = drain } } };
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const this: *ChunkingWriter = @alignCast(@fieldParentPtr("interface", w));
        const buffered = w.buffered();
        if (buffered.len > 0) this.response.chunk(buffered) catch return error.WriteFailed;
        w.end = 0;
        var n: usize = 0;
        for (data[0 .. data.len - 1]) |slice| {
            if (slice.len > 0) this.response.chunk(slice) catch return error.WriteFailed;
            n = n + slice.len;
        }
        const last = data[data.len - 1];
        for (0 .. splat) |_| {
            if (last.len > 0) this.response.chunk(last) catch return error.WriteFailed;
        }
        return n + splat * last.len;
    }
};


pub const ZipWriter = struct {
    w: *std.Io.Writer,
    entries: std.ArrayList(Entry) = .empty,
    offset: u64 = 0,
    state: ZipState = .status_writing,

    const utf_8_flag: u16 = 1 << 11;
    const data_descriptor_flag: u16 = 1 << 3;
    const zip64_version: u16 = 45;

    pub fn init(w: *std.Io.Writer, start_offset: u64) ZipWriter {
        return .{ .w = w, .offset = start_offset };
    }

    pub fn deinit(self: *ZipWriter, allocator: std.mem.Allocator) void {
        for (self.entries.items) |entry| allocator.free(entry.name);
        self.entries.deinit(allocator);
        self.* = undefined;
    }

    pub fn add_path_recursive(self: *ZipWriter, io: std.Io, allocator: std.mem.Allocator, root: std.Io.Dir, relative_path: []const u8, base_in_zip: []const u8) !void {
        try self.require_writing();
        try utils.validate_relative_path(relative_path);

        const normalized_base = try normalize_zip_base(allocator, base_in_zip);
        defer allocator.free(normalized_base);

        errdefer self.state = .status_failed;

        var current = root;
        var current_is_owned = false;
        defer if (current_is_owned) current.close(io);

        const separators = if (builtin.os.tag == .windows) "/\\" else "/";
        var components = std.mem.tokenizeAny(u8, relative_path, separators);
        var component = components.next() orelse return error.InvalidPath;
        while (components.next()) |next| {
            const child = try current.openDir(io, component, .{ .iterate = false, .follow_symlinks = false });
            if (current_is_owned) current.close(io);
            current = child;
            current_is_owned = true;
            component = next;
        }

        const stat = try current.statFile(io, component, .{ .follow_symlinks = false });
        switch (stat.kind) {
            .directory => {
                var dir = try current.openDir(io, component, .{ .iterate = true, .follow_symlinks = false });
                defer dir.close(io);
                try self.add_directory_tree(io, allocator, dir, normalized_base);
            },
            .file => {
                const file = try current.openFile(io, component, .{ .follow_symlinks = false, .resolve_beneath = true });
                defer file.close(io);
                const archive_name = if (normalized_base.len == 0) component else normalized_base;
                try self.add_regular_file(io, allocator, file, archive_name);
            },
            .sym_link => return error.SymbolicLinkNotAllowed,
            else => return error.UnsupportedFileType,
        }
    }

    pub fn finish(self: *ZipWriter) !void {
        try self.require_writing();
        errdefer self.state = .status_failed;

        const central_directory_start = self.offset;
        for (self.entries.items) |entry| try self.write_central_directory_entry(entry);

        const central_directory_size = self.offset - central_directory_start;
        const entry_count: u64 = @intCast(self.entries.items.len);
        const zip64_eocd_offset = self.offset;
        var zip64_eocd: [56]u8 = undefined;

        std.mem.writeInt(u32, zip64_eocd[0 .. 4], 0x06064b50, .little);
        std.mem.writeInt(u64, zip64_eocd[4 .. 12], 44, .little);
        std.mem.writeInt(u16, zip64_eocd[12 .. 14], zip64_version, .little);
        std.mem.writeInt(u16, zip64_eocd[14 .. 16], zip64_version, .little);
        std.mem.writeInt(u32, zip64_eocd[16 .. 20], 0, .little);
        std.mem.writeInt(u32, zip64_eocd[20 .. 24], 0, .little);
        std.mem.writeInt(u64, zip64_eocd[24 .. 32], entry_count, .little);
        std.mem.writeInt(u64, zip64_eocd[32 .. 40], entry_count, .little);
        std.mem.writeInt(u64, zip64_eocd[40 .. 48], central_directory_size, .little);
        std.mem.writeInt(u64, zip64_eocd[48 .. 56], central_directory_start, .little);
        try self.write_bytes(&zip64_eocd);

        var locator: [20]u8 = undefined;
        std.mem.writeInt(u32, locator[0 .. 4], 0x07064b50, .little);
        std.mem.writeInt(u32, locator[4 .. 8], 0, .little);
        std.mem.writeInt(u64, locator[8 .. 16], zip64_eocd_offset, .little);
        std.mem.writeInt(u32, locator[16 .. 20], 1, .little);
        try self.write_bytes(&locator);

        var eocd: [22]u8 = undefined;
        std.mem.writeInt(u32, eocd[0 .. 4], 0x06054b50, .little);
        std.mem.writeInt(u16, eocd[4 .. 6], 0, .little);
        std.mem.writeInt(u16, eocd[6 .. 8], 0, .little);
        std.mem.writeInt(u16, eocd[8 .. 10], std.math.maxInt(u16), .little);
        std.mem.writeInt(u16, eocd[10 .. 12], std.math.maxInt(u16), .little);
        std.mem.writeInt(u32, eocd[12 .. 16], std.math.maxInt(u32), .little);
        std.mem.writeInt(u32, eocd[16 .. 20], std.math.maxInt(u32), .little);
        std.mem.writeInt(u16, eocd[20 .. 22], 0, .little);
        try self.write_bytes(&eocd);

        try self.w.flush();
        self.state = .status_finished;
    }

    fn write_central_directory_entry(self: *ZipWriter, entry: Entry) !void {
        const needs_zip64_size = entry.size >= std.math.maxInt(u32);
        const needs_zip64_offset = entry.offset >= std.math.maxInt(u32);
        const zip64_data_len: u16 = (if (needs_zip64_size) @as(u16, 16) else 0) + (if (needs_zip64_offset) @as(u16, 8) else 0);
        const extra_len: u16 = if (zip64_data_len == 0) 0 else zip64_data_len + 4;
        const version_needed: u16 = if (needs_zip64_size or needs_zip64_offset) zip64_version else 20;

        var header: [46]u8 = undefined;
        std.mem.writeInt(u32, header[0 .. 4], 0x02014b50, .little);
        std.mem.writeInt(u16, header[4 .. 6], zip64_version, .little);
        std.mem.writeInt(u16, header[6 .. 8], version_needed, .little);

        const flags = utf_8_flag | if (entry.is_directory) 0 else data_descriptor_flag;
        std.mem.writeInt(u16, header[8 .. 10], flags, .little);
        std.mem.writeInt(u16, header[10 .. 12], 0, .little);
        std.mem.writeInt(u16, header[12 .. 14], 0, .little);
        std.mem.writeInt(u16, header[14 .. 16], 0x21, .little);
        std.mem.writeInt(u32, header[16 .. 20], entry.crc, .little);
        std.mem.writeInt(u32, header[20 .. 24], if (needs_zip64_size) std.math.maxInt(u32) else @intCast(entry.size), .little);
        std.mem.writeInt(u32, header[24 .. 28], if (needs_zip64_size) std.math.maxInt(u32) else @intCast(entry.size), .little);
        std.mem.writeInt(u16, header[28 .. 30], @intCast(entry.name.len), .little);
        std.mem.writeInt(u16, header[30 .. 32], extra_len, .little);
        std.mem.writeInt(u16, header[32 .. 34], 0, .little);
        std.mem.writeInt(u16, header[34 .. 36], 0, .little);
        std.mem.writeInt(u16, header[36 .. 38], 0, .little);
        std.mem.writeInt(u32, header[38 .. 42], if (entry.is_directory) 0x10 else 0, .little);
        std.mem.writeInt(u32, header[42 .. 46], if (needs_zip64_offset) std.math.maxInt(u32) else @intCast(entry.offset), .little);
        try self.write_bytes(&header);
        try self.write_bytes(entry.name);

        if (zip64_data_len != 0) {
            var extra: [28]u8 = undefined;
            std.mem.writeInt(u16, extra[0 .. 2], 0x0001, .little);
            std.mem.writeInt(u16, extra[2 .. 4], zip64_data_len, .little);
            var index: usize = 4;
            if (needs_zip64_size) {
                std.mem.writeInt(u64, extra[index .. ][0 .. 8], entry.size, .little);
                std.mem.writeInt(u64, extra[index + 8 .. ][0 .. 8], entry.size, .little);
                index = index + 16;
            }
            if (needs_zip64_offset) {
                std.mem.writeInt(u64, extra[index .. ][0 .. 8], entry.offset, .little);
                index = index + 8;
            }
            try self.write_bytes(extra[0 .. index]);
        }
    }

    fn add_directory_tree(self: *ZipWriter, io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir, base_in_zip: []const u8) !void {
        if (base_in_zip.len != 0) {
            const directory_name = try std.fmt.allocPrint(allocator, "{s}/", .{base_in_zip});
            defer allocator.free(directory_name);
            try self.add_directory_entry(allocator, directory_name);
        }

        var iterator = dir.iterate();
        while (try iterator.next(io)) |entry| {
            const child_in_zip = if (base_in_zip.len == 0) try allocator.dupe(u8, entry.name) else try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_in_zip, entry.name });
            defer allocator.free(child_in_zip);

            const kind = if (entry.kind == .unknown) (try dir.statFile(io, entry.name, .{ .follow_symlinks = false })).kind else entry.kind;

            switch (kind) {
                .directory => {
                    var child_dir = try dir.openDir(io, entry.name, .{ .iterate = true, .follow_symlinks = false });
                    defer child_dir.close(io);
                    try self.add_directory_tree(io, allocator, child_dir, child_in_zip);
                },
                .file => {
                    const file = try dir.openFile(io, entry.name, .{ .follow_symlinks = false, .resolve_beneath = true });
                    defer file.close(io);
                    try self.add_regular_file(io, allocator, file, child_in_zip);
                },
                .sym_link => return error.SymbolicLinkNotAllowed,
                else => return error.UnsupportedFileType,
            }
        }
    }

    fn add_directory_entry(self: *ZipWriter, allocator: std.mem.Allocator, raw_name: []const u8) !void {
        const name = try self.prepare_name(allocator, raw_name);
        errdefer allocator.free(name);
        try self.entries.ensureUnusedCapacity(allocator, 1);

        const start_offset = self.offset;
        try self.write_local_header(name, 0, false);
        self.entries.appendAssumeCapacity(.{ .name = name, .crc = 0, .size = 0, .offset = start_offset, .is_directory = true });
    }

    fn add_regular_file(self: *ZipWriter, io: std.Io, allocator: std.mem.Allocator, file: std.Io.File, raw_name: []const u8) !void {
        const name = try self.prepare_name(allocator, raw_name);
        errdefer allocator.free(name);
        try self.entries.ensureUnusedCapacity(allocator, 1);

        const expected_size = (try file.stat(io)).size;
        const needs_zip64_size = expected_size >= std.math.maxInt(u32);
        const start_offset = self.offset;
        try self.write_local_header(name, expected_size, true);

        var reader_buffer: [16 * 1024]u8 = undefined;
        var read_buffer: [64 * 1024]u8 = undefined;
        var reader = file.reader(io, &reader_buffer);
        var crc_engine = std.hash.crc.Crc32IsoHdlc.init();
        var copied_size: u64 = 0;

        while (true) {
            const count = try reader.interface.readSliceShort(&read_buffer);
            if (count == 0) break;
            crc_engine.update(read_buffer[0 .. count]);
            copied_size = try std.math.add(u64, copied_size, count);
            if (!needs_zip64_size and copied_size >= std.math.maxInt(u32)) return error.FileChangedDuringArchive;
            try self.write_bytes(read_buffer[0 .. count]);
        }
        if (copied_size != expected_size) return error.FileChangedDuringArchive;
        const crc = crc_engine.final();
        try self.write_data_descriptor(crc, copied_size, needs_zip64_size);

        self.entries.appendAssumeCapacity(
            .{
                .name = name,
                .crc = crc,
                .size = copied_size,
                .offset = start_offset,
                .is_directory = false
            }
        );
    }

    fn write_data_descriptor(self: *ZipWriter, crc: u32, size: u64, use_zip64: bool) !void {
        if (use_zip64) {
            var descriptor: [24]u8 = undefined;
            std.mem.writeInt(u32, descriptor[0 .. 4], 0x08074b50, .little);
            std.mem.writeInt(u32, descriptor[4 .. 8], crc, .little);
            std.mem.writeInt(u64, descriptor[8 .. 16], size, .little);
            std.mem.writeInt(u64, descriptor[16 .. 24], size, .little);
            try self.write_bytes(&descriptor);
        } else {
            var descriptor: [16]u8 = undefined;
            std.mem.writeInt(u32, descriptor[0 .. 4], 0x08074b50, .little);
            std.mem.writeInt(u32, descriptor[4 .. 8], crc, .little);
            std.mem.writeInt(u32, descriptor[8 .. 12], @intCast(size), .little);
            std.mem.writeInt(u32, descriptor[12 .. 16], @intCast(size), .little);
            try self.write_bytes(&descriptor);
        }
    }

    fn write_local_header(self: *ZipWriter, name: []const u8, size: u64, use_data_descriptor: bool) !void {
        const needs_zip64_size = size >= std.math.maxInt(u32);
        const name_len: u16 = @intCast(name.len);
        const extra_len: u16 = if (needs_zip64_size) 20 else 0;
        const version: u16 = if (needs_zip64_size) zip64_version else 20;
        const flags = utf_8_flag | if (use_data_descriptor) data_descriptor_flag else 0;
        const size32: u32 = if (needs_zip64_size) std.math.maxInt(u32) else if (use_data_descriptor) 0 else @intCast(size);

        var header: [30]u8 = undefined;
        std.mem.writeInt(u32, header[0 .. 4], 0x04034b50, .little);
        std.mem.writeInt(u16, header[4 .. 6], version, .little);
        std.mem.writeInt(u16, header[6 .. 8], flags, .little);
        std.mem.writeInt(u16, header[8 .. 10], 0, .little); // STORED
        std.mem.writeInt(u16, header[10 .. 12], 0, .little);
        std.mem.writeInt(u16, header[12 .. 14], 0x21, .little); // 1980-01-01
        std.mem.writeInt(u32, header[14 .. 18], 0, .little);
        std.mem.writeInt(u32, header[18 .. 22], size32, .little);
        std.mem.writeInt(u32, header[22 .. 26], size32, .little);
        std.mem.writeInt(u16, header[26 .. 28], name_len, .little);
        std.mem.writeInt(u16, header[28 .. 30], extra_len, .little);
        try self.write_bytes(&header);
        try self.write_bytes(name);

        if (needs_zip64_size) {
            var extra: [20]u8 = undefined;
            std.mem.writeInt(u16, extra[0 .. 2], 0x0001, .little);
            std.mem.writeInt(u16, extra[2 .. 4], 16, .little);
            std.mem.writeInt(u64, extra[4 .. 12], size, .little);
            std.mem.writeInt(u64, extra[12 .. 20], size, .little);
            try self.write_bytes(&extra);
        }
    }

    fn require_writing(self: *const ZipWriter) !void {
        return switch (self.state) {
            .status_writing => {},
            .status_finished => error.ZipWriterAlreadyFinished,
            .status_failed => error.ZipWriterFailed,
        };
    }

    fn write_bytes(self: *ZipWriter, bytes: []const u8) !void {
        self.w.writeAll(bytes) catch |err| {
            self.state = .status_failed;
            return err;
        };
        self.offset = std.math.add(u64, self.offset, bytes.len) catch {
            self.state = .status_failed;
            return error.ZipArchiveTooLarge;
        };
    }

    fn prepare_name(_: *const ZipWriter, allocator: std.mem.Allocator, raw_name: []const u8) ![]u8 {
        const name = try allocator.dupe(u8, raw_name);
        errdefer allocator.free(name);
        for (name) |*byte| if (byte.* == '\\') {
            byte.* = '/';
        };
        try validate_zip_path(name);
        return name;
    }

    fn normalize_zip_base(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
        if (raw.len == 0) return allocator.dupe(u8, "");
        if (raw[0] == '/' or raw[0] == '\\' or utils.is_windows_drive_prefix(raw)) return error.InvalidZipEntryName;

        var end = raw.len;
        while (end > 0 and (raw[end - 1] == '/' or raw[end - 1] == '\\')) end = end - 1;
        if (end == 0) return error.InvalidZipEntryName;

        const normalized = try allocator.dupe(u8, raw[0 .. end]);
        errdefer allocator.free(normalized);
        for (normalized) |*byte| if (byte.* == '\\') {
            byte.* = '/';
        };
        try validate_zip_path(normalized);
        return normalized;
    }

    fn validate_zip_path(name: []const u8) !void {
        if (name.len == 0 or name.len > std.math.maxInt(u16)) return error.InvalidZipEntryName;
        if (!std.unicode.utf8ValidateSlice(name)) return error.InvalidUtf8FileName;
        if (std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidZipEntryName;
        if (name[0] == '/' or utils.is_windows_drive_prefix(name)) return error.InvalidZipEntryName;

        const path = if (std.mem.endsWith(u8, name, "/")) name[0 .. name.len - 1] else name;
        if (path.len == 0 or std.mem.indexOf(u8, path, "//") != null) return error.InvalidZipEntryName;

        var components = std.mem.splitScalar(u8, path, '/');
        while (components.next()) |component| {
            if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) {
                return error.InvalidZipEntryName;
            }
        }
    }
};
