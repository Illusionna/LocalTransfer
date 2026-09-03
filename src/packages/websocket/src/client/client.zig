const std = @import("std");

const posix = @import("../posix.zig");
const proto = @import("../proto.zig");
const buffer = @import("../buffer.zig");
const CompressionOpts = @import("../websocket.zig").Compression;
const ServerHandshake = @import("../server/handshake.zig").Handshake;

const Io = std.Io;
const ascii = std.ascii;
const tls = std.crypto.tls;
const log = std.log.scoped(.websocket);

const Reader = proto.Reader;
const Allocator = std.mem.Allocator;
const Bundle = std.crypto.Certificate.Bundle;

fn ReadLoopHandler(comptime T: type) type {
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => |struct_info| {
            if (struct_info.is_tuple)
                @compileError("readLoop: handler does not support tuples.");

            return T;
        },
        .pointer => |ptr_info| {
            switch (ptr_info.size) {
                .one => return ReadLoopHandler(ptr_info.child),
                else => @compileError("readLoop: handler does not support Slice, C and Many pointers."),
            }
        },
        else => @compileError("readLoop: expected handler to be a struct or pointer to a struct but found '" ++ @tagName(info) ++ "'"),
    }
}

// Resolve `host` and connect to `port` with the TCP connect bounded by
// `timeout_ms`. The Threaded Io panics when asked for a connect timeout, so the
// connect is driven manually: a non-blocking connect gated by poll(). The
// returned stream's socket is left in blocking mode for the handshake and read
// paths.
fn connectTimeout(io: Io, host: []const u8, port: u16, timeout_ms: u32) !Io.net.Stream {
    const host_name = try Io.net.HostName.init(host);

    if ((comptime @import("builtin").os.tag == .windows) or timeout_ms == 0) {
        return host_name.connect(io, port, .{ .mode = .stream });
    }

    var lookup_buf: [32]Io.net.HostName.LookupResult = undefined;
    var lookup_queue = Io.Queue(Io.net.HostName.LookupResult).init(&lookup_buf);
    var lookup_future = io.async(Io.net.HostName.lookup, .{ host_name, io, &lookup_queue, .{ .port = port } });
    defer lookup_future.cancel(io) catch {};

    // A single deadline spans every resolved address. DNS can return many
    // records, so giving each attempt a full timeout_ms would let a hostile
    // relay stretch the total connect wait to N x timeout_ms and outlast the
    // shutdown grace. Each attempt gets only the remaining budget; once it is
    // exhausted we stop and report the last error.
    const start_ns = Io.Timestamp.now(io, .awake).nanoseconds;
    var last_err: ?ConnectAddrError = null;
    while (lookup_queue.getOneUncancelable(io)) |res| switch (res) {
        .address => |addr| {
            const elapsed = @divTrunc(Io.Timestamp.now(io, .awake).nanoseconds - start_ns, std.time.ns_per_ms);
            if (elapsed >= timeout_ms) return error.ConnectTimeout;
            const remaining: u32 = if (elapsed <= 0) timeout_ms else timeout_ms - @as(u32, @intCast(elapsed));
            return connectAddrTimeout(addr, remaining) catch |err| {
                last_err = err;
                continue;
            };
        },
        .canonical_name => continue,
    } else |err| switch (err) {
        error.Closed => {},
    }
    if (last_err) |err| {
        return err;
    }
    // No addresses at all: surface the resolver's error if it had one.
    try lookup_future.await(io);
    return error.UnknownHostName;
}

const ConnectAddrError = error{ ConnectFailed, ConnectTimeout, ConnectionRefused, NetworkUnreachable };

fn connectAddrTimeout(addr: Io.net.IpAddress, timeout_ms: u32) ConnectAddrError!Io.net.Stream {
    const address: posix.Address = switch (addr) {
        .ip4 => |a| .{ .in = .{
            .port = std.mem.nativeToBig(u16, a.port),
            .addr = @bitCast(a.bytes),
        } },
        .ip6 => |a| .{ .in6 = .{
            .port = std.mem.nativeToBig(u16, a.port),
            .flowinfo = a.flow,
            .addr = a.bytes,
            // Required for link-local (fe80::) addresses to pick the right
            // interface; Interface.none has index 0.
            .scope_id = a.interface.index,
        } },
    };

    const sock_type = posix.SOCK.STREAM | posix.NONBLOCK | posix.CLOEXEC;
    const fd = posix.socket(@intCast(address.any.family), sock_type, 0) catch return error.ConnectFailed;
    errdefer posix.close(fd);

    if (posix.connect(fd, &address.any, address.getOsSockLen())) |_| {
        // Connected without blocking.
    } else |err| switch (err) {
        error.WouldBlock => {
            var pfd = [_]std.posix.pollfd{.{ .fd = fd, .events = std.posix.POLL.OUT, .revents = 0 }};
            // poll()'s timeout is a signed c_int; a misconfigured timeout larger
            // than INT_MAX would panic on the cast, so clamp instead.
            const poll_ms: i32 = @intCast(@min(timeout_ms, @as(u32, std.math.maxInt(i32))));
            const ready = std.posix.poll(&pfd, poll_ms) catch return error.ConnectFailed;
            if (ready == 0) return error.ConnectTimeout;
            // poll() readiness does not imply success: an async connect failure
            // is reported via SO_ERROR and need not set POLL.ERR/HUP, so this is
            // the authoritative check.
            var so_err: i32 = 0;
            var so_len: posix.socklen_t = @sizeOf(i32);
            switch (std.posix.errno(posix.system.getsockopt(fd, posix.SOL.SOCKET, posix.SO.ERROR, @ptrCast(&so_err), &so_len))) {
                .SUCCESS => {},
                else => return error.ConnectFailed,
            }
            if (so_err != 0) return switch (@as(std.posix.E, @enumFromInt(so_err))) {
                .CONNREFUSED => error.ConnectionRefused,
                .TIMEDOUT => error.ConnectTimeout,
                .HOSTUNREACH, .NETUNREACH => error.NetworkUnreachable,
                else => error.ConnectFailed,
            };
        },
        error.ConnectionRefused => return error.ConnectionRefused,
        error.NetworkUnreachable => return error.NetworkUnreachable,
        error.ConnectionTimedOut => return error.ConnectTimeout,
        else => return error.ConnectFailed,
    }

    // The handshake and read/write paths expect a blocking socket.
    const nonblock: usize = @as(u32, @bitCast(std.posix.O{ .NONBLOCK = true }));
    const flags = posix.fcntl(fd, posix.F.GETFL, 0) catch return error.ConnectFailed;
    _ = posix.fcntl(fd, posix.F.SETFL, flags & ~nonblock) catch return error.ConnectFailed;

    return .{ .socket = .{ .handle = fd, .address = addr } };
}

// Bounds the TLS handshake: a thread waits up to `timeout_ms` on a wake pipe
// and, if the handshake has not finished by then, shuts the socket down so the
// blocking handshake read/write fails instead of hanging. `disarm` wakes the
// thread and joins it before the socket may be closed, so it never touches a
// reused fd.
const HandshakeGuard = struct {
    wake_r: posix.fd_t,
    wake_w: posix.fd_t,
    thread: std.Thread,

    fn arm(fd: posix.socket_t, timeout_ms: u32, timed_out: *std.atomic.Value(bool)) !HandshakeGuard {
        const fds = try posix.pipe2(.{ .CLOEXEC = true });
        errdefer {
            posix.close(fds[0]);
            posix.close(fds[1]);
        }
        const thread = try std.Thread.spawn(.{}, watch, .{ fd, timeout_ms, fds[0], timed_out });
        return .{ .wake_r = fds[0], .wake_w = fds[1], .thread = thread };
    }

    fn watch(fd: posix.socket_t, timeout_ms: u32, wake_r: posix.fd_t, timed_out: *std.atomic.Value(bool)) void {
        var pfd = [_]std.posix.pollfd{.{ .fd = wake_r, .events = std.posix.POLL.IN, .revents = 0 }};
        const poll_ms: i32 = @intCast(@min(timeout_ms, @as(u32, std.math.maxInt(i32))));
        const ready = std.posix.poll(&pfd, poll_ms) catch return;
        if (ready == 0) {
            timed_out.store(true, .release);
            posix.shutdown(fd, .both) catch {};
        }
    }

    fn disarm(self: *HandshakeGuard) void {
        _ = posix.write(self.wake_w, "x") catch {};
        self.thread.join();
        posix.close(self.wake_r);
        posix.close(self.wake_w);
    }
};

// The TLS handshake reads/writes on a blocking socket, so it cannot be
// time-bounded from the caller (a socket receive timeout surfaces as EAGAIN,
// which std.crypto.tls treats as a bug). A watchdog that shuts the socket down
// forces those blocking operations to fail instead of hanging; the timed_out
// flag then reports that failure as a timeout rather than as the read error
// the shutdown provoked.
fn initTLSClientTimeout(io: Io, allocator: Allocator, net_stream: Io.net.Stream, config: *const Client.Config) !*TLSClient {
    if (comptime @import("builtin").os.tag == .windows) {
        // HandshakeGuard is POSIX-only (pipe + poll); see connectTimeout.
        return TLSClient.init(io, allocator, net_stream, config);
    }
    if (config.connect_timeout_ms == 0) {
        return TLSClient.init(io, allocator, net_stream, config);
    }

    var timed_out: std.atomic.Value(bool) = .init(false);
    var guard = try HandshakeGuard.arm(net_stream.socket.handle, config.connect_timeout_ms, &timed_out);
    const tls_client = TLSClient.init(io, allocator, net_stream, config) catch |err| {
        guard.disarm();
        if (timed_out.load(.acquire)) return error.TlsHandshakeTimeout;
        return err;
    };
    guard.disarm();
    if (timed_out.load(.acquire)) {
        // The watchdog fired just as the handshake completed: the socket has
        // been shut down, so the "successful" client is unusable.
        tls_client.deinit();
        return error.TlsHandshakeTimeout;
    }
    return tls_client;
}

pub const Client = struct {
    io: Io,
    stream: Stream,
    _reader: Reader,
    _closed: bool,
    _compression_opts: ?CompressionOpts,
    _compression: ?Client.Compression = null,

    // When creating a client, we can either be given a BufferProvider or create
    // one ourselves. If we create it ourselves (in init), we "own" it and must
    // free it on deinit. (The reference to the buffer provider is already in the
    // reader, no need to hold another reference in the client).
    _own_bp: bool,

    // For advanced cases, a custom masking function can be provided. Masking
    // is a security feature that only really makes sense in the browser. If you
    // aren't running websockets in the browser AND you control both the client
    // and the server, you could get a performance boost by not masking.
    _mask_fn: *const fn (Io) [4]u8,

    pub const Config = struct {
        port: u16,
        host: []const u8,
        tls: bool = false,
        max_size: usize = 65536,
        buffer_size: usize = 4096,
        ca_bundle: ?Bundle = null,
        mask_fn: *const fn (Io) [4]u8 = generateMask,
        buffer_provider: ?*buffer.Provider = null,
        compression: ?CompressionOpts = null,
        // Upper bound (ms) applied independently to the TCP connect and the TLS
        // handshake, so a blackholed or stalling relay cannot hang init() (and
        // thus a clean shutdown) indefinitely. The real bound on init() is
        // DNS + connect + handshake: connect and handshake are each bounded by
        // this value (a single deadline spans all resolved addresses on the
        // connect side), so the two together are ~2x this value. DNS resolution
        // is NOT bounded — the Threaded Io cannot cancel host_name.lookup — so a
        // hung resolver is a known residual outside this bound.
        // 0 disables the timeout (consistent with readTimeout). On Windows the
        // timeout is currently not enforced: the enforcement mechanisms are
        // POSIX-only and the std Io api cannot yet bound a connect.
        connect_timeout_ms: u32 = 10000,
    };

    pub const HandshakeOpts = struct {
        timeout_ms: u32 = 10000,
        headers: ?[]const u8 = null,
    };

    const Compression = struct {
        allocator: Allocator,
        retain_writer: bool,
        write_treshold: usize,
        writer: Io.Writer.Allocating,
    };

    pub fn init(io: Io, allocator: Allocator, config: Config) !Client {
        if (config.compression != null) {
            log.err("Compression is disabled as part of the 0.15 upgrade. I do hope to re-enable it soon.", .{});
            return error.InvalidConfiguraion;
        }

        const net_stream = try connectTimeout(io, config.host, config.port, config.connect_timeout_ms);
        // Own the connected socket for the rest of init: on any later failure
        // (TLS handshake, buffer-provider create, reader_buf alloc) this closes
        // the fd so it can't leak on either the TLS or non-TLS path. On success
        // no errdefer fires and the fd is moved into the returned Client.
        errdefer net_stream.close(io);

        var tls_client: ?*TLSClient = null;
        if (config.tls) {
            tls_client = try initTLSClientTimeout(io, allocator, net_stream, &config);
        }
        const stream = Stream.init(io, net_stream, tls_client);

        var own_bp = false;
        var buffer_provider: *buffer.Provider = undefined;

        // If a buffer_provider is provided, we'll use that.
        // If it isn't, we need to create one which also means we now "own" it
        // and we're responsible for cleaning it up
        if (config.buffer_provider) |shared_bp| {
            buffer_provider = shared_bp;
        } else {
            own_bp = true;
            buffer_provider = try allocator.create(buffer.Provider);
            errdefer allocator.destroy(buffer_provider);
            buffer_provider.* = try buffer.Provider.init(io, allocator, .{
                .size = 0,
                .count = 0,
                .max = config.max_size,
            });
        }

        errdefer if (own_bp) {
            buffer_provider.deinit();
            allocator.destroy(buffer_provider);
        };

        const reader_buf = try buffer_provider.allocator.alloc(u8, config.buffer_size);
        errdefer buffer_provider.allocator.free(reader_buf);

        return .{
            .io = io,
            .stream = stream,
            ._closed = false,
            ._own_bp = own_bp,
            ._mask_fn = config.mask_fn,
            ._compression_opts = null, //TODO: ZIG 0.15
            ._reader = Reader.init(reader_buf, buffer_provider, null),
        };
    }

    pub fn deinit(self: *Client) void {
        self.closeStream();

        const larger_buffer_provider = self._reader.large_buffer_provider;
        const allocator = larger_buffer_provider.allocator;
        allocator.free(self._reader.static);

        self._reader.deinit();

        if (self._own_bp) {
            larger_buffer_provider.deinit();
            allocator.destroy(larger_buffer_provider);
        }
    }

    pub fn handshake(self: *Client, path: []const u8, opts: HandshakeOpts) !void {
        const stream = &self.stream;
        errdefer self.closeStream();

        // we've already setup our reader, and the reader has a static buffer
        // we might as well use it!
        const buf = self._reader.static;
        const key = blk: {
            const bin_key = generateKey(self.io);
            var encoded_key: [24]u8 = undefined;
            break :blk std.base64.standard.Encoder.encode(&encoded_key, &bin_key);
        };

        try sendHandshake(path, key, buf, &opts, self._compression_opts != null, stream);

        const res = try HandShakeReply.read(self.io, buf, key, &opts, self._compression_opts != null, stream);
        errdefer self.close(.{ .code = 1001 }) catch unreachable;

        // Set up compression with agreed-on parameters
        if (res.compression) {
            try self.setupCompression();
        }

        // We might have read more than handshake response. If so, readHandshakeReply
        // has positioned the extra data at the start of the buffer, but we need
        // to set the length.
        self._reader.pos = res.over_read;
    }

    fn setupCompression(self: *Client) !void {
        std.debug.assert(self._compression_opts != null);
        self._reader.allow_compressed = true;

        const allocator = self._reader.large_buffer_provider.allocator;
        const config = self._compression_opts.?;
        self._compression = .{
            .allocator = allocator,
            .write_treshold = config.write_threshold.?,
            .retain_writer = config.retain_write_buffer,
            .writer = std.Io.Writer.Allocating.init(allocator),
        };
    }

    pub fn readLoop(self: *Client, handler: anytype) !void {
        const Handler = ReadLoopHandler(@TypeOf(handler));
        var reader = &self._reader;

        defer if (comptime std.meta.hasFn(Handler, "close")) {
            handler.close();
        };

        // block until we have data
        try self.readTimeout(0);

        while (true) {
            const message = self.read() catch |err| switch (err) {
                error.Closed => return,
                else => return err,
            } orelse unreachable;

            const message_type = message.type;
            defer reader.done(message_type);

            switch (message_type) {
                .text, .binary => {
                    switch (comptime @typeInfo(@TypeOf(Handler.serverMessage)).@"fn".params.len) {
                        2 => try handler.serverMessage(message.data),
                        3 => try handler.serverMessage(message.data, if (message_type == .text) .text else .binary),
                        else => @compileError(@typeName(Handler) ++ ".serverMessage must accept 2 or 3 parameters"),
                    }
                },
                .ping => if (comptime std.meta.hasFn(Handler, "serverPing")) {
                    try handler.serverPing(message.data);
                } else {
                    // @constCast is safe because we know message.data points to
                    // reader.buffer.buf, which we own and which can be mutated
                    try self.writeFrame(.pong, @constCast(message.data));
                },
                .close => {
                    if (comptime std.meta.hasFn(Handler, "serverClose")) {
                        try handler.serverClose(message.data);
                    } else {
                        self.close(.{}) catch unreachable;
                    }
                    return;
                },
                .pong => if (comptime std.meta.hasFn(Handler, "serverPong")) {
                    try handler.serverPong(message.data);
                },
            }
        }
    }

    pub fn read(self: *Client) !?proto.Message {
        var reader = &self._reader;
        const stream = &self.stream;

        while (true) {
            // try to read a message from our buffer first, before trying to
            // get more data from the socket.
            const has_more, const message = reader.read() catch |err| {
                self.close(.{ .code = 1002 }) catch unreachable;
                return err;
            } orelse {
                reader.fill(stream) catch |err| switch (err) {
                    error.WouldBlock => return null,
                    error.Closed, error.ConnectionResetByPeer, error.BrokenPipe, error.NotOpenForReading => {
                        @atomicStore(bool, &self._closed, true, .monotonic);
                        return error.Closed;
                    },
                    else => {
                        self.close(.{ .code = 1002 }) catch unreachable;
                        return err;
                    },
                };
                continue;
            };

            _ = has_more;
            return message;
        }
    }

    pub fn done(self: *Client, message: proto.Message) void {
        self._reader.done(message.type);
    }

    pub fn readLoopInNewThread(self: *Client, h: anytype) !std.Thread {
        return std.Thread.spawn(.{}, readLoopOwnedThread, .{ self, h });
    }

    fn readLoopOwnedThread(self: *Client, h: anytype) void {
        self.readLoop(h) catch {};
    }

    pub fn writeTimeout(self: *const Client, ms: u32) !void {
        return self.stream.writeTimeout(ms);
    }

    pub fn readTimeout(self: *Client, ms: u32) !void {
        return self.stream.readTimeout(ms);
    }

    pub fn write(self: *Client, data: []u8) !void {
        return self.writeFrame(.text, data);
    }

    pub fn writeText(self: *Client, data: []u8) !void {
        return self.writeFrame(.text, data);
    }

    pub fn writeBin(self: *Client, data: []u8) !void {
        return self.writeFrame(.binary, data);
    }

    pub fn writePing(self: *Client, data: []u8) !void {
        return self.writeFrame(.ping, data);
    }

    pub fn writePong(self: *Client, data: []u8) !void {
        return self.writeFrame(.pong, data);
    }

    const CloseOpts = struct {
        code: ?u16 = null,
        reason: []const u8 = "",
    };

    pub fn close(self: *Client, opts: CloseOpts) !void {
        if (@atomicRmw(bool, &self._closed, .Xchg, true, .monotonic) == true) {
            // already closed
            return;
        }

        defer self.stream.close();

        const code = opts.code orelse {
            self.writeFrame(.close, "") catch {};
            return;
        };

        const reason = opts.reason;
        if (reason.len > 123) {
            return error.ReasonTooLong;
        }

        var buf: [125]u8 = undefined;
        buf[0] = @intCast((code >> 8) & 0xFF);
        buf[1] = @intCast(code & 0xFF);

        const end = 2 + reason.len;
        @memcpy(buf[2..end], reason);
        self.writeFrame(.close, buf[0..end]) catch {};
    }

    pub fn writeFrame(self: *Client, op_code: proto.OpCode, data: []u8) !void {
        const payload = data;
        const compressed = false;
        // if (self._compression) |c| {
        //     if (data.len >= c.write_treshold and (op_code == .binary or op_code == .text)) {
        //         compressed = true;

        //         var writer = &c.writer;
        //         var compressor = &c.compressor;
        //         var fbs = std.io.fixedBufferStream(data);
        //         _ = try compressor.compress(fbs.reader());
        //         try compressor.flush();
        //         payload = writer.items[0 .. writer.items.len - 4];

        //         if (c.reset) {
        //             c.compressor = try Compression.Type.init(writer.writer(), .{});
        //         }
        //     }
        // }
        // defer if (compressed) {
        //     const c = self._compression.?;
        //     if (c.retain_writer) {
        //         c.compressor.wrt.context.clearRetainingCapacity();
        //     } else {
        //         c.compressor.wrt.context.clearAndFree();
        //     }
        // };

        // maximum possible prefix length. op_code + length_type + 8byte length + 4 byte mask
        var buf: [14]u8 = undefined;
        const header = proto.writeFrameHeader(&buf, op_code, payload.len, compressed);

        const header_len = header.len;
        const header_end = header.len + 4; // for the mask

        buf[1] |= 128; // indicate that the payload is masked

        const mask = self._mask_fn(self.io);
        @memcpy(buf[header_len..header_end], &mask);
        try self.stream.writeAll(buf[0..header_end]);

        if (payload.len > 0) {
            proto.mask(&mask, payload);
            try self.stream.writeAll(payload);
        }
    }

    fn closeStream(self: *Client) void {
        if (@atomicRmw(bool, &self._closed, .Xchg, true, .monotonic) == false) {
            self.stream.close();
        }
    }
};

pub const Stream = struct {
    io: Io,
    stream: Io.net.Stream,
    tls_client: ?*TLSClient = null,
    read_timeout_ms: u32 = 0,

    pub fn init(io: Io, stream: Io.net.Stream, tls_client: ?*TLSClient) Stream {
        return .{
            .io = io,
            .stream = stream,
            .tls_client = tls_client,
        };
    }

    pub fn close(self: *Stream) void {
        const fd = self.stream.socket.handle;
        const builtin = @import("builtin");
        const native_os = builtin.os.tag;

        if (self.tls_client) |tls_client| {
            // Shutdown the socket first, so readLoop() can exit, before tls_client's buffers are freed
            if (native_os == .wasi and !builtin.link_libc) {
                _ = std.os.wasi.sock_shutdown(fd, .{ .WR = true, .RD = true });
            } else {
                posix.shutdown(fd, .both) catch {};
            }
            tls_client.deinit();
        }

        // posix.close panics on EBADF
        // This is a general issue in Zig:
        // https://github.com/ziglang/zig/issues/6389
        //
        // we don't want to crash on double close

        if (native_os == .windows) {
            return std.os.windows.CloseHandle(fd);
        }
        if (native_os == .wasi and !builtin.link_libc) {
            _ = std.os.wasi.fd_close(fd);
            return;
        }
        _ = std.posix.system.close(fd);
    }

    pub fn read(self: *Stream, buf: []u8) !usize {
        if (self.tls_client) |tls_client| {
            var w: std.Io.Writer = .fixed(buf);
            while (true) {
                // The TLS reader decrypts into its own buffer; stream() returns
                // >0 only once that buffer holds plaintext. A single stream()
                // will often (typically?) returns 0 without yielding a plaintext
                // message. We have to loop until we get a visible message..
                if (tls_client.client.reader.bufferedLen() == 0 and !hasBufferedTlsRecord(tls_client.client.input) and !try self.pollReadable()) {
                    return error.WouldBlock;
                }
                const n = try tls_client.client.reader.stream(&w, .limited(buf.len));
                if (n != 0) {
                    return n;
                }
            }
        }
        if (comptime @import("builtin").os.tag == .windows) {
            var data = [_][]u8{buf};
            // netRead returns net.Stream.Reader.Error which includes Timeout,
            // SocketUnconnected, NetworkDown, etc. – map all to ReadFailed
            // to keep the inferred error set compatible with callers.
            return self.io.vtable.netRead(self.io.userdata, self.stream.socket.handle, &data) catch |err| switch (err) {
                error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
                else => return error.ReadFailed,
            };
        }
        if (!try self.pollReadable()) {
            return error.WouldBlock;
        }
        return posix.read(self.stream.socket.handle, buf);
    }

    // Ciphertext already drained off the socket sits in
    // tls_client.client.input, invisible to poll(). If a complete
    // record is buffered there, stream() can decrypt it without
    // touching the socket, so we must not poll (the socket may
    // legitimately be empty). But a *partial* record makes stream()
    // do a blocking socket read to complete it, so in that case we
    // still poll to honor the read timeout.
    fn hasBufferedTlsRecord(input: *std.Io.Reader) bool {
        const buffered = input.buffered();
        if (buffered.len < std.crypto.tls.record_header_len) {
            return false;
        }
        const record_len = std.mem.readInt(u16, buffered[3..5], .big);
        return buffered.len >= std.crypto.tls.record_header_len + record_len;
    }

    fn pollReadable(self: *Stream) !bool {
        if (comptime @import("builtin").os.tag == .windows) {
            return true;
        }
        if (self.read_timeout_ms == 0) {
            return true;
        }
        var pfd = [_]std.posix.pollfd{.{
            .fd = self.stream.socket.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};
        // poll()'s timeout is a signed c_int. Clamp rather than cast: a timeout
        // above INT_MAX panics in safe builds, and in ReleaseFast wraps to a
        // negative value, which makes poll() block forever and silently defeats
        // the timeout it is implementing.
        const poll_ms: i32 = @intCast(@min(self.read_timeout_ms, @as(u32, std.math.maxInt(i32))));
        // A poll failure is a real read failure, not "no data": surface it
        // (mapped into this read path's error set) rather than swallowing it.
        const ready = std.posix.poll(&pfd, poll_ms) catch return error.ReadFailed;
        return ready != 0;
    }

    pub fn writeAll(self: *Stream, data: []const u8) !void {
        if (self.tls_client) |tls_client| {
            try tls_client.client.writer.writeAll(data);
            // I know this looks silly, but as far as I can tell, this is what
            // we need to do.
            try tls_client.client.writer.flush();
            try tls_client.stream_writer.interface.flush();
            return;
        }

        var writer = self.stream.writer(self.io, &.{});
        try writer.interface.writeAll(data);
        return writer.interface.flush();
    }

    const zero_timeout = std.mem.toBytes(posix.timeval{ .sec = 0, .usec = 0 });
    pub fn writeTimeout(self: *const Stream, ms: u32) !void {
        return self.setTimeout(posix.SO.SNDTIMEO, ms);
    }

    pub fn readTimeout(self: *Stream, ms: u32) !void {
        // Stored and applied via poll() in read(); see the note there for why this
        // does not use SO_RCVTIMEO.
        self.read_timeout_ms = ms;
    }

    fn setTimeout(self: *const Stream, opt_name: u32, ms: u32) !void {
        if (ms == 0) {
            return self.setsockopt(opt_name, &zero_timeout);
        }

        const timeout = std.mem.toBytes(posix.timeval{
            .sec = @intCast(@divTrunc(ms, 1000)),
            .usec = @intCast(@mod(ms, 1000) * 1000),
        });
        return self.setsockopt(opt_name, &timeout);
    }

    pub fn setsockopt(self: *const Stream, opt_name: u32, value: []const u8) !void {
        return posix.setsockopt(self.stream.socket.handle, posix.SOL.SOCKET, opt_name, value);
    }
};

const TLSClient = struct {
    io: Io,
    client: tls.Client,
    stream: Io.net.Stream,
    stream_writer: Io.net.Stream.Writer,
    stream_reader: Io.net.Stream.Reader,
    arena: std.heap.ArenaAllocator,

    fn init(io: Io, allocator: Allocator, stream: Io.net.Stream, config: *const Client.Config) !*TLSClient {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const aa = arena.allocator();

        // 0.16: Bundle is heap-allocated so we can pass a pointer to TLS
        // Options.ca.bundle. A single-threaded RwLock is fine here because
        // the bundle is only touched by this TLS client; the RwLock serves
        // only to match the Options.ca.bundle contract.
        const bundle_ptr = try aa.create(Bundle);
        if (config.ca_bundle) |existing| {
            bundle_ptr.* = existing;
        } else {
            bundle_ptr.* = .empty;
            // 0.16: rescan signature is (*Bundle, gpa, io, now: Io.Timestamp).
            try bundle_ptr.rescan(aa, io, Io.Timestamp.now(io, .real));
        }
        const bundle_lock = try aa.create(Io.RwLock);
        bundle_lock.* = .init;

        // The TLS input and output have to be max_ciphertext_record_len each.
        // It isn't clear to me how big the un-encrypted reader and writer
        // need to be. I would think 0, but that will fail an assertion. I
        // don't think that it's right that we need 4 buffers, but apparently
        // we do. Until i figure this out, using 4 x max_ciphertext_record_len
        // seems like the only safe choice.
        const buf_len = std.crypto.tls.max_ciphertext_record_len;
        var buf = try aa.alloc(u8, buf_len * 4);

        const self = try aa.create(TLSClient);
        self.* = .{
            .io = io,
            .stream = stream,
            .arena = arena,
            .client = undefined,
            .stream_writer = stream.writer(io, buf.ptr[0..buf_len][0..buf_len]),
            .stream_reader = stream.reader(io, buf.ptr[buf_len .. 2 * buf_len][0..buf_len]),
        };

        // 0.16 TLS Client.Options requires `entropy` and `realtime_now` in
        // addition to the 0.15 set. Fill both from the shim Io — the
        // entropy buffer is read only during `init`.
        var entropy_buf: [tls.Client.Options.entropy_len]u8 = undefined;
        io.random(&entropy_buf);

        self.client = try tls.Client.init(
            &self.stream_reader.interface,
            &self.stream_writer.interface,
            .{
                .ca = .{ .bundle = .{
                    .gpa = aa,
                    .io = io,
                    .lock = bundle_lock,
                    .bundle = bundle_ptr,
                } },
                .host = .{ .explicit = config.host },
                .read_buffer = buf.ptr[2 * buf_len .. 3 * buf_len][0..buf_len],
                .write_buffer = buf.ptr[3 * buf_len .. 4 * buf_len][0..buf_len],
                .entropy = &entropy_buf,
                .realtime_now = std.Io.Timestamp.now(io, .real),
            },
        );

        return self;
    }

    fn deinit(self: *TLSClient) void {
        _ = self.client.end() catch {};
        self.arena.deinit();
    }
};

fn generateKey(io: Io) [16]u8 {
    if (comptime @import("builtin").is_test) {
        return [16]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    }
    var key: [16]u8 = undefined;
    io.random(&key);
    return key;
}

fn generateMask(io: Io) [4]u8 {
    var m: [4]u8 = undefined;
    io.random(&m);
    return m;
}

fn sendHandshake(path: []const u8, key: []const u8, buf: []u8, opts: *const Client.HandshakeOpts, compression: bool, stream: anytype) !void {
    @memcpy(buf[0..4], "GET ");
    var pos: usize = 4;
    var end = pos + path.len;

    {
        @memcpy(buf[pos..end], path);
        pos = end;
    }

    {
        const headers = " HTTP/1.1\r\ncontent-length: 0\r\nupgrade: websocket\r\nsec-websocket-version: 13\r\nconnection: upgrade\r\nsec-websocket-key: ";
        end = pos + headers.len;
        @memcpy(buf[pos..end], headers);

        pos = end;
        end = pos + key.len;
        @memcpy(buf[pos..end], key);
    }

    if (compression) {
        // NOTE: client_max_window_bits is unsupported
        const permessage_deflate = "\r\nSec-WebSocket-Extensions: permessage-deflate; server_no_context_takeover; client_no_context_takeover";
        pos = end;
        end = pos + permessage_deflate.len;
        @memcpy(buf[pos..end], permessage_deflate);
    }

    {
        pos = end;
        end = pos + 2;
        @memcpy(buf[pos..end], "\r\n");
        pos = end;
    }

    if (opts.headers) |extra_headers| {
        end = pos + extra_headers.len;
        @memcpy(buf[pos..end], extra_headers);
        pos = end;
        if (!std.mem.endsWith(u8, extra_headers, "\r\n")) {
            buf[pos] = '\r';
            buf[pos + 1] = '\n';
            pos += 2;
        }
    }
    buf[pos] = '\r';
    buf[pos + 1] = '\n';

    try stream.writeTimeout(opts.timeout_ms);
    try stream.writeAll(buf[0 .. pos + 2]);
    try stream.writeTimeout(0);
}

const HandShakeReply = struct {
    compression: bool,
    over_read: usize,

    fn read(io: Io, buf: []u8, key: []const u8, opts: *const Client.HandshakeOpts, compression: bool, stream: anytype) !HandShakeReply {
        const timeout_ms = opts.timeout_ms;
        // 0.16 removed `std.time.milliTimestamp`; compute ms since epoch
        // from `std.Io.Timestamp.now(io, .real)` (nanoseconds).
        const deadline = @divTrunc(Io.Timestamp.now(io, .real).nanoseconds, std.time.ns_per_ms) + timeout_ms;
        try stream.readTimeout(timeout_ms);

        var pos: usize = 0;
        var line_start: usize = 0;
        var complete_response: u8 = 0;
        var server_compression: bool = false;

        while (true) {
            const n = stream.read(buf[pos..]) catch |err| {
                // `error.WouldBlock` may not be in `err`'s set on Windows
                // (where the read goes through ReadFile), so match by name.
                if (std.mem.eql(u8, @errorName(err), "WouldBlock")) return error.Timeout;
                return err;
            };
            if (n == 0) {
                return error.ConnectionClosed;
            }

            pos += n;
            while (std.mem.indexOfScalar(u8, buf[line_start..pos], '\r')) |relative_end| {
                if (relative_end == 0) {
                    if (complete_response != 15) {
                        return error.InvalidHandshakeResponse;
                    }
                    const over_read = pos - (line_start + 2);
                    std.mem.copyForwards(u8, buf[0..over_read], buf[line_start + 2 .. pos]);
                    try stream.readTimeout(0);
                    return .{
                        .over_read = over_read,
                        .compression = server_compression,
                    };
                }

                const line_end = line_start + relative_end;
                const line = buf[line_start..line_end];

                // the next line starts where this line ends, skip over the \r\n
                line_start = line_end + 2;

                if (complete_response == 0) {
                    if (!ascii.startsWithIgnoreCase(line, "HTTP/1.1 101 ")) {
                        return error.InvalidHandshakeResponse;
                    }
                    complete_response |= 1;
                    continue;
                }

                for (line, 0..) |b, i| {
                    // find the colon and lowercase the header while we're iterating
                    if ('A' <= b and b <= 'Z') {
                        line[i] = b + 32;
                        continue;
                    }

                    if (b != ':') {
                        continue;
                    }

                    switch (i) {
                        7 => if (std.mem.eql(u8, line[0..i], "upgrade")) {
                            if (!ascii.eqlIgnoreCase(std.mem.trim(u8, line[i + 1 ..], &ascii.whitespace), "websocket")) {
                                return error.InvalidUpgradeHeader;
                            }
                            complete_response |= 2;
                        },
                        10 => if (std.mem.eql(u8, line[0..i], "connection")) {
                            if (!ascii.eqlIgnoreCase(std.mem.trim(u8, line[i + 1 ..], &ascii.whitespace), "upgrade")) {
                                return error.InvalidConnectionHeader;
                            }
                            complete_response |= 4;
                        },
                        20 => if (std.mem.eql(u8, line[0..i], "sec-websocket-accept")) {
                            var h: [20]u8 = undefined;
                            {
                                var hasher = std.crypto.hash.Sha1.init(.{});
                                hasher.update(key);
                                hasher.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
                                hasher.final(&h);
                            }

                            var encoded_buf: [28]u8 = undefined;
                            const sec_hash = std.base64.standard.Encoder.encode(&encoded_buf, &h);
                            const header_value = std.mem.trim(u8, line[i + 1 ..], &ascii.whitespace);

                            if (!std.mem.eql(u8, header_value, sec_hash)) {
                                return error.InvalidWebsocketAcceptHeader;
                            }
                            complete_response |= 8;
                        },
                        24 => if (std.mem.eql(u8, line[0..i], "sec-websocket-extensions")) {
                            if (try parseExtension(line[i + 1 ..])) |sc| {
                                if (!compression) {
                                    // server is saying compression, but we didn't ask for it.
                                    return error.InvalidExtensionHeader;
                                }
                                if (!sc.client_no_context_takeover or !sc.server_no_context_takeover) {
                                    // as of Zig 0.15, we no longer support context takeover
                                    // We told the server this, it should have respected it.
                                    return error.InvalidExtensionHeader;
                                }

                                server_compression = true;
                            }
                        },
                        else => {}, // some other header we don't care about
                    }
                }
            }

            if (@divTrunc(Io.Timestamp.now(io, .real).nanoseconds, std.time.ns_per_ms) > deadline) {
                return error.Timeout;
            }

            if (pos == buf.len) {
                return error.ResponseTooLarge;
            }
        }
    }

    pub fn parseExtension(value: []const u8) !?ServerHandshake.Compression {
        var deflate = false;
        var client_max_bits: u8 = 15;
        var client_no_context_takeover = false;
        var server_no_context_takeover = false;

        var it = std.mem.splitScalar(u8, value, ';');
        while (it.next()) |param_| {
            const param = std.mem.trim(u8, param_, &ascii.whitespace);
            if (std.mem.eql(u8, param, "permessage-deflate")) {
                deflate = true;
                continue;
            }
            if (std.mem.eql(u8, param, "client_no_context_takeover")) {
                client_no_context_takeover = true;
                continue;
            }
            if (std.mem.eql(u8, param, "server_no_context_takeover")) {
                server_no_context_takeover = true;
                continue;
            }
            const client_max_window_bits = "client_max_window_bits=";
            if (std.mem.startsWith(u8, param, client_max_window_bits)) {
                client_max_bits = std.fmt.parseInt(u8, param[client_max_window_bits.len..], 10) catch {
                    return error.InvalidCompressionServerMaxBits;
                };
            }
        }
        if (deflate == false) {
            return null;
        }

        if (client_max_bits != 15) {
            // We don't offer client window, so if the server asks for one, that's an error
            return error.InvalidExtensionHeader;
        }

        return .{
            .client_no_context_takeover = client_no_context_takeover,
            .server_no_context_takeover = server_no_context_takeover,
        };
    }
};

const t = @import("../t.zig");
test "Client: handshake" {
    {
        // empty response
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidHandshakeResponse, client.handshake("/", .{}));
    }

    {
        // invalid websocket response
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 200 OK\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidHandshakeResponse, client.handshake("/", .{}));
    }

    {
        // missing upgrade header
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidHandshakeResponse, client.handshake("/", .{}));
    }

    {
        // wrong upgrade header
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\nUpgrade: nope\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidUpgradeHeader, client.handshake("/", .{}));
    }

    {
        // missing connection header
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\nUpgrade: websocket\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidHandshakeResponse, client.handshake("/", .{}));
    }

    {
        // wrong connection header
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\nupgrade: WebSocket\r\nConnection: something\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidConnectionHeader, client.handshake("/", .{}));
    }

    {
        // missing Sec-Websocket-Accept header
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\nUpgrade: websocket\r\nConnection: upgrade\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidHandshakeResponse, client.handshake("/", .{}));
    }

    {
        // wrong Sec-Websocket-Accept header
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\nupgrade: WebSocket\r\nConnection: UPGRADE\r\nSec-Websocket-Accept: hack\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try t.expectError(error.InvalidWebsocketAcceptHeader, client.handshake("/", .{}));
    }

    {
        // ok for successful
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\nupgrade: WebSocket\r\nConnection: UPGRADE\r\nSec-Websocket-Accept: C/0nmHhBztSRGR1CwL6Tf4ZjwpY=\r\n\r\n");

        var client = testClient(pair.server);
        defer client.deinit();
        try client.handshake("/", .{});
        try t.expectEqual(0, client._reader.pos);
    }

    {
        // ok for successful, with overread
        var pair = t.SocketPair.init(.{});
        defer pair.deinit();
        var writer = pair.client.writer(t.io, &.{});
        try writer.interface.writeAll("HTTP/1.1 101 Switching Protocol\r\nupgrade: WebSocket\r\nConnection: UPGRADE\r\nSec-Websocket-Accept: C/0nmHhBztSRGR1CwL6Tf4ZjwpY=\r\n\r\nSome Random Data Which is Part Of the Next Message");

        var client = testClient(pair.server);
        defer client.deinit();
        try client.handshake("/", .{});
        try t.expectEqual(50, client._reader.pos);
    }
}

test "Client: write/read" {
    var client = try Client.init(t.io, t.allocator, .{
        .port = 9292,
        .host = "127.0.0.1",
    });
    defer client.deinit();

    try client.handshake("/", .{
        .timeout_ms = 1000,
    });

    var buf = [_]u8{ 'o', 'v', 'e', 'r' };
    try client.write(&buf);
    try client.readTimeout(1000);

    const message = (try client.read()) orelse unreachable;
    try t.expectEqual(.text, message.type);
    try t.expectString("9000", message.data);

    client.close(.{}) catch unreachable;
}

test "Client: close with code" {
    var client = try Client.init(t.io, t.allocator, .{
        .port = 9292,
        .host = "127.0.0.1",
    });
    defer client.deinit();

    try client.handshake("/", .{
        .timeout_ms = 1000,
    });

    client.close(.{ .code = 4002 }) catch unreachable;
}

test "Client: with code and reason" {
    var client = try Client.init(t.io, t.allocator, .{
        .port = 9292,
        .host = "127.0.0.1",
    });
    defer client.deinit();

    try client.handshake("/", .{
        .timeout_ms = 1000,
    });

    client.close(.{ .code = 4002, .reason = "goodbye" }) catch unreachable;
}

test "Client: Handler" {
    var h = try ClientHandler.init(t.io, t.allocator);
    defer h.deinit();

    var buf: [6]u8 = undefined;
    {
        @memcpy(buf[0..3], "dyn");
        try h.client.write(buf[0..3]);
    }

    {
        @memcpy(buf[0..4], "ping");
        try h.client.write(buf[0..4]);
    }

    {
        @memcpy(buf[0..4], "pong");
        try h.client.write(buf[0..4]);
    }

    {
        @memcpy(buf[0..6], "close1");
        try h.client.write(buf[0..6]);
    }

    try h.client.readLoop(&h);

    // if pong is true then ping and message have to be true
    // because each asserts the previous
    try t.expectEqual(true, h.pong);
    try t.expectEqual(true, h.closed);
}

fn testClient(stream: Io.net.Stream) Client {
    const bp = t.allocator.create(buffer.Provider) catch unreachable;
    bp.* = buffer.Provider.init(t.io, t.allocator, .{ .count = 0, .size = 0, .max = 4096 }) catch unreachable;

    const reader_buf = bp.allocator.alloc(u8, 1024) catch unreachable;

    return .{
        .io = t.io,
        ._closed = false,
        ._own_bp = true,
        ._mask_fn = generateMask,
        ._compression_opts = null,
        .stream = .{ .io = t.io, .stream = stream },
        ._reader = Reader.init(reader_buf, bp, null),
    };
}

const ClientHandler = struct {
    ping: bool = false,
    pong: bool = false,
    closed: bool = false,
    message: bool = false,
    client: Client,

    fn init(io: Io, allocator: Allocator) !ClientHandler {
        var client = try Client.init(io, allocator, .{
            .port = 9292,
            .host = "127.0.0.1",
        });
        errdefer client.deinit();

        try client.handshake("/", .{
            .timeout_ms = 1000,
        });

        return .{
            .client = client,
        };
    }

    fn deinit(self: *ClientHandler) void {
        self.client.deinit();
    }

    pub fn serverMessage(self: *ClientHandler, data: []u8, tpe: proto.Message.TextType) !void {
        try t.expectEqual(.text, tpe);
        try t.expectString("over 9000!", data);
        self.message = true;
    }

    pub fn serverPing(self: *ClientHandler, data: []u8) !void {
        try t.expectEqual(true, self.message);
        try t.expectString("a-ping", data);
        self.ping = true;
    }

    pub fn serverPong(self: *ClientHandler, data: []u8) !void {
        try t.expectEqual(true, self.ping);
        try t.expectString("a-pong", data);
        self.pong = true;
    }

    pub fn close(self: *ClientHandler) void {
        self.client.close(.{}) catch unreachable;
        self.closed = true;
    }
};
