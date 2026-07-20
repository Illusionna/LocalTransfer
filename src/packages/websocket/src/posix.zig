const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");

const posix = std.posix;
pub const system = posix.system;

pub const O = system.O;
pub const F = system.F;
pub const AF = posix.AF;
pub const SO = posix.SO;
pub const SOL = posix.SOL;
pub const SOCK = posix.SOCK;
pub const fd_t = posix.fd_t;
pub const socket_t = posix.socket_t;
pub const timeval = posix.timeval;
pub const IPPROTO = posix.IPPROTO;
pub const sockaddr = posix.sockaddr;
pub const timespec = posix.timespec;
pub const socklen_t = posix.socklen_t;
pub const Kevent = system.Kevent;

const native_os = builtin.os.tag;

/// WARNING: this flag is not supported by windows socket functions directly,
///          it is only supported by std.os.socket. Be sure that this value does
///          not share any bits with any of the `SOCK` values.
pub const CLOEXEC = if (native_os == .windows) 0x10000 else SOCK.CLOEXEC;
pub const NONBLOCK = if (native_os == .windows) 0x20000 else SOCK.NONBLOCK;

pub fn socket(domain: u32, socket_type: u32, protocol: u32) !socket_t {
    if (native_os == .windows) {
        // These flags are not actually part of the Windows API, instead they are converted here for compatibility
        const filtered_sock_type = socket_type & ~@as(u32, NONBLOCK | CLOEXEC);
        var flags: u32 = windows.ws2_32.WSA_FLAG_OVERLAPPED;
        if ((socket_type & CLOEXEC) != 0) flags |= windows.ws2_32.WSA_FLAG_NO_HANDLE_INHERIT;

        const rc = try windows.WSASocketW(
            @bitCast(domain),
            @bitCast(filtered_sock_type),
            @bitCast(protocol),
            null,
            0,
            flags,
        );
        errdefer windows.closesocket(rc) catch unreachable;
        if ((socket_type & NONBLOCK) != 0) {
            var mode: c_ulong = 1; // nonblocking
            if (windows.ws2_32.SOCKET_ERROR == windows.ws2_32.ioctlsocket(rc, windows.ws2_32.FIONBIO, &mode)) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    // have not identified any error codes that should be handled yet
                    else => unreachable,
                }
            }
        }
        return rc;
    }

    const have_sock_flags = !builtin.target.os.tag.isDarwin() and native_os != .haiku;
    const filtered_sock_type = if (!have_sock_flags)
        socket_type & ~@as(u32, NONBLOCK | CLOEXEC)
    else
        socket_type;
    const rc = posix.system.socket(domain, filtered_sock_type, protocol);
    switch (posix.errno(rc)) {
        .SUCCESS => {
            const fd: fd_t = @intCast(rc);
            errdefer close(fd);
            if (!have_sock_flags) {
                try setSockFlags(fd, socket_type);
            }
            return fd;
        },
        .ACCES => return error.AccessDenied,
        .AFNOSUPPORT => return error.AddressFamilyNotSupported,
        .INVAL => return error.ProtocolFamilyNotAvailable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOBUFS => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        .PROTONOSUPPORT => return error.ProtocolNotSupported,
        .PROTOTYPE => return error.SocketTypeNotSupported,
        else => return error.Unexpected,
    }
}

fn setSockFlags(sock: socket_t, flags: u32) !void {
    if ((flags & CLOEXEC) != 0) {
        if (native_os == .windows) {
            // TODO: Find out if this is supported for sockets
        } else {
            var fd_flags = fcntl(sock, F.GETFD, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fd_flags |= system.FD_CLOEXEC;
            _ = fcntl(sock, F.SETFD, fd_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
        }
    }
    if ((flags & NONBLOCK) != 0) {
        if (native_os == .windows) {
            var mode: c_ulong = 1;
            if (windows.ws2_32.ioctlsocket(sock, windows.ws2_32.FIONBIO, &mode) == windows.ws2_32.SOCKET_ERROR) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSANOTINITIALISED => unreachable,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                    // TODO: handle more errors
                    else => |err| return windows.unexpectedWSAError(err),
                }
            }
        } else {
            var fl_flags = fcntl(sock, F.GETFL, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fl_flags |= 1 << @bitOffsetOf(O, "NONBLOCK");
            _ = fcntl(sock, F.SETFL, fl_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
        }
    }
}

pub fn fcntl(fd: fd_t, cmd: i32, arg: usize) !usize {
    while (true) {
        const rc = posix.system.fcntl(fd, cmd, arg);
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .AGAIN, .ACCES => return error.Locked,
            .BADF => unreachable,
            .BUSY => return error.FileBusy,
            .INVAL => unreachable, // invalid parameters
            .PERM => return error.PermissionDenied,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NOTDIR => unreachable, // invalid parameter
            .DEADLK => return error.DeadLock,
            .NOLCK => return error.LockedRegionLimitExceeded,
            else => return error.Unexpected,
        }
    }
}

pub fn close(fd: fd_t) void {
    if (native_os == .windows) {
        // websocket.zig only ever closes socket handles here; closesocket is
        // the proper Winsock teardown (CloseHandle bypasses refcounting).
        windows.closesocket(fd) catch {};
        return;
    }
    switch (posix.errno(system.close(fd))) {
        .BADF => unreachable, // Always a race condition.
        .INTR => return, // This is still a success. See https://github.com/ziglang/zig/issues/2425
        else => return,
    }
}

pub fn setsockopt(fd: socket_t, level: i32, optname: u32, opt: []const u8) !void {
    if (native_os == .windows) {
        // Winsock takes SO_RCVTIMEO/SO_SNDTIMEO as a DWORD of milliseconds,
        // not a struct timeval. Translate so callers can stay portable.
        var ms_buf: u32 = 0;
        var opt_ptr: [*]const u8 = opt.ptr;
        var opt_len: i32 = @intCast(opt.len);
        if (level == SOL.SOCKET and (optname == SO.RCVTIMEO or optname == SO.SNDTIMEO) and opt.len == @sizeOf(timeval)) {
            const tv: *const timeval = @ptrCast(@alignCast(opt.ptr));
            const total_ms = @as(i64, tv.sec) * 1000 + @divTrunc(@as(i64, tv.usec), 1000);
            ms_buf = if (total_ms < 0) 0 else @intCast(@min(total_ms, std.math.maxInt(u32)));
            opt_ptr = @ptrCast(&ms_buf);
            opt_len = @sizeOf(u32);
        }
        const rc = windows.ws2_32.setsockopt(fd, level, @intCast(optname), opt_ptr, opt_len);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEFAULT => unreachable,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEINVAL => return error.SocketNotBound,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        switch (posix.errno(system.setsockopt(fd, level, optname, opt.ptr, @intCast(opt.len)))) {
            .SUCCESS => {},
            .BADF => unreachable, // always a race condition
            .NOTSOCK => unreachable, // always a race condition
            .INVAL => unreachable,
            .FAULT => unreachable,
            .DOM => return error.TimeoutTooBig,
            .ISCONN => return error.AlreadyConnected,
            .NOPROTOOPT => return error.InvalidProtocolOption,
            .NOMEM => return error.SystemResources,
            .NOBUFS => return error.SystemResources,
            .PERM => return error.PermissionDenied,
            .NODEV => return error.NoDevice,
            .OPNOTSUPP => return error.OperationNotSupported,
            else => return error.Unexpected,
        }
    }
}

pub fn bind(sock: socket_t, addr: *const sockaddr, len: socklen_t) !void {
    if (native_os == .windows) {
        const rc = windows.bind(sock, addr, len);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable, // not initialized WSA
                .WSAEACCES => return error.AccessDenied,
                .WSAEADDRINUSE => return error.AddressInUse,
                .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEFAULT => unreachable, // invalid pointers
                .WSAEINVAL => return error.AlreadyBound,
                .WSAENOBUFS => return error.SystemResources,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                else => |err| return windows.unexpectedWSAError(err),
            }
            unreachable;
        }
        return;
    } else {
        const rc = system.bind(sock, addr, len);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            .ACCES, .PERM => return error.AccessDenied,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => unreachable, // always a race condition if this error is returned
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => unreachable, // invalid `sockfd`
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .ADDRNOTAVAIL => return error.AddressNotAvailable,
            .FAULT => unreachable, // invalid `addr` pointer
            .LOOP => return error.SymLinkLoop,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            else => return error.Unexpected,
        }
    }
    unreachable;
}

pub fn connect(sock: socket_t, sock_addr: *const sockaddr, len: socklen_t) !void {
    if (native_os == .windows) {
        const rc = windows.ws2_32.connect(sock, sock_addr, @intCast(len));
        if (rc == 0) return;
        switch (windows.ws2_32.WSAGetLastError()) {
            .WSAEADDRINUSE => return error.AddressInUse,
            .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
            .WSAECONNREFUSED => return error.ConnectionRefused,
            .WSAECONNRESET => return error.ConnectionResetByPeer,
            .WSAETIMEDOUT => return error.ConnectionTimedOut,
            .WSAEHOSTUNREACH, // TODO: should we return NetworkUnreachable in this case as well?
            .WSAENETUNREACH,
            => return error.NetworkUnreachable,
            .WSAEFAULT => unreachable,
            .WSAEINVAL => unreachable,
            .WSAEISCONN => unreachable,
            .WSAENOTSOCK => unreachable,
            .WSAEWOULDBLOCK => return error.WouldBlock,
            .WSAEACCES => unreachable,
            .WSAENOBUFS => return error.SystemResources,
            .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
            else => |err| return windows.unexpectedWSAError(err),
        }
        return;
    }

    while (true) {
        switch (posix.errno(system.connect(sock, sock_addr, len))) {
            .SUCCESS => return,
            .ACCES => return error.AccessDenied,
            .PERM => return error.PermissionDenied,
            .ADDRINUSE => return error.AddressInUse,
            .ADDRNOTAVAIL => return error.AddressNotAvailable,
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .AGAIN, .INPROGRESS => return error.WouldBlock,
            .ALREADY => return error.ConnectionPending,
            .BADF => unreachable, // sockfd is not a valid open file descriptor.
            .CONNREFUSED => return error.ConnectionRefused,
            .CONNRESET => return error.ConnectionResetByPeer,
            .FAULT => unreachable, // The socket structure address is outside the user's address space.
            .INTR => continue,
            .ISCONN => unreachable, // The socket is already connected.
            .HOSTUNREACH => return error.NetworkUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            .PROTOTYPE => unreachable, // The socket type does not support the requested communications protocol.
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NOENT => return error.FileNotFound, // Returned when socket is AF.UNIX and the given path does not exist.
            .CONNABORTED => unreachable, // Tried to reuse socket that previously received error.ConnectionRefused.
            else => return error.Unexpected,
        }
    }
}

pub const Address = extern union {
    any: posix.sockaddr,
    in: posix.sockaddr.in,
    in6: posix.sockaddr.in6,
    un: if (@hasDecl(posix.sockaddr, "un")) posix.sockaddr.un else posix.sockaddr,

    pub fn initUnix(path: []const u8) !Address {
        var sock_addr = posix.sockaddr.un{
            .family = AF.UNIX,
            .path = undefined,
        };

        // Add 1 to ensure a terminating 0 is present in the path array for maximum portability.
        if (path.len + 1 > sock_addr.path.len) {
            return error.NameTooLong;
        }

        @memset(&sock_addr.path, 0);
        @memcpy(sock_addr.path[0..path.len], path);

        return .{ .un = sock_addr };
    }

    pub fn parseIp(name: []const u8, port: u16) !Address {
        if (parseIp4(name, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.NonCanonical,
            => {},
        }

        if (parseIp6(name, port)) |ip6| return ip6 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.InvalidIpv4Mapping,
            => {},
        }

        return error.InvalidIPAddressFormat;
    }

    pub fn parseIp4(buf: []const u8, port: u16) !Address {
        const socket_address = blk: {
            var sa = posix.sockaddr.in{
                .port = std.mem.nativeToBig(u16, port),
                .addr = undefined,
            };
            const out_ptr = std.mem.asBytes(&sa.addr);

            var x: u8 = 0;
            var index: u8 = 0;
            var saw_any_digits = false;
            var has_zero_prefix = false;
            for (buf) |c| {
                if (c == '.') {
                    if (!saw_any_digits) {
                        return error.InvalidCharacter;
                    }
                    if (index == 3) {
                        return error.InvalidEnd;
                    }
                    out_ptr[index] = x;
                    index += 1;
                    x = 0;
                    saw_any_digits = false;
                    has_zero_prefix = false;
                } else if (c >= '0' and c <= '9') {
                    if (c == '0' and !saw_any_digits) {
                        has_zero_prefix = true;
                    } else if (has_zero_prefix) {
                        return error.NonCanonical;
                    }
                    saw_any_digits = true;
                    x = try std.math.mul(u8, x, 10);
                    x = try std.math.add(u8, x, c - '0');
                } else {
                    return error.InvalidCharacter;
                }
            }
            if (index == 3 and saw_any_digits) {
                out_ptr[index] = x;
                break :blk sa;
            }

            return error.Incomplete;
        };
        return .{ .in = socket_address };
    }

    pub fn parseIp6(buf: []const u8, port: u16) !Address {
        const socket_address = blk: {
            var sa = posix.sockaddr.in6{
                .scope_id = 0,
                .port = std.mem.nativeToBig(u16, port),
                .flowinfo = 0,
                .addr = undefined,
            };
            var ip_slice: *[16]u8 = sa.addr[0..];

            var tail: [16]u8 = undefined;

            var x: u16 = 0;
            var saw_any_digits = false;
            var index: u8 = 0;
            var scope_id = false;
            var abbrv = false;
            for (buf, 0..) |c, i| {
                if (scope_id) {
                    if (c >= '0' and c <= '9') {
                        const digit = c - '0';
                        {
                            const ov = @mulWithOverflow(sa.scope_id, 10);
                            if (ov[1] != 0) return error.Overflow;
                            sa.scope_id = ov[0];
                        }
                        {
                            const ov = @addWithOverflow(sa.scope_id, digit);
                            if (ov[1] != 0) return error.Overflow;
                            sa.scope_id = ov[0];
                        }
                    } else {
                        return error.InvalidCharacter;
                    }
                } else if (c == ':') {
                    if (!saw_any_digits) {
                        if (abbrv) return error.InvalidCharacter; // ':::'
                        if (i != 0) abbrv = true;
                        @memset(ip_slice[index..], 0);
                        ip_slice = tail[0..];
                        index = 0;
                        continue;
                    }
                    if (index == 14) {
                        return error.InvalidEnd;
                    }
                    ip_slice[index] = @as(u8, @truncate(x >> 8));
                    index += 1;
                    ip_slice[index] = @as(u8, @truncate(x));
                    index += 1;

                    x = 0;
                    saw_any_digits = false;
                } else if (c == '%') {
                    if (!saw_any_digits) {
                        return error.InvalidCharacter;
                    }
                    scope_id = true;
                    saw_any_digits = false;
                } else if (c == '.') {
                    if (!abbrv or ip_slice[0] != 0xff or ip_slice[1] != 0xff) {
                        // must start with '::ffff:'
                        return error.InvalidIpv4Mapping;
                    }
                    const start_index = std.mem.lastIndexOfScalar(u8, buf[0..i], ':').? + 1;
                    const addr = (parseIp4(buf[start_index..], 0) catch {
                        return error.InvalidIpv4Mapping;
                    }).in.addr;
                    ip_slice = sa.addr[0..];
                    ip_slice[10] = 0xff;
                    ip_slice[11] = 0xff;

                    const ptr = std.mem.sliceAsBytes(@as(*const [1]u32, &addr)[0..]);

                    ip_slice[12] = ptr[0];
                    ip_slice[13] = ptr[1];
                    ip_slice[14] = ptr[2];
                    ip_slice[15] = ptr[3];
                    break :blk sa;
                } else {
                    const digit = try std.fmt.charToDigit(c, 16);
                    {
                        const ov = @mulWithOverflow(x, 16);
                        if (ov[1] != 0) return error.Overflow;
                        x = ov[0];
                    }
                    {
                        const ov = @addWithOverflow(x, digit);
                        if (ov[1] != 0) return error.Overflow;
                        x = ov[0];
                    }
                    saw_any_digits = true;
                }
            }

            if (!saw_any_digits and !abbrv) {
                return error.Incomplete;
            }
            if (!abbrv and index < 14) {
                return error.Incomplete;
            }

            if (index == 14) {
                ip_slice[14] = @as(u8, @truncate(x >> 8));
                ip_slice[15] = @as(u8, @truncate(x));
                break :blk sa;
            } else {
                ip_slice[index] = @as(u8, @truncate(x >> 8));
                index += 1;
                ip_slice[index] = @as(u8, @truncate(x));
                index += 1;
                @memcpy(sa.addr[16 - index ..][0..index], ip_slice[0..index]);
                break :blk sa;
            }
        };
        return .{ .in6 = socket_address };
    }

    pub fn getOsSockLen(self: Address) posix.socklen_t {
        return switch (self.any.family) {
            posix.AF.INET => @sizeOf(posix.sockaddr.in),
            posix.AF.INET6 => @sizeOf(posix.sockaddr.in6),
            posix.AF.UNIX => if (@hasDecl(posix.sockaddr, "un"))
                @intCast(@offsetOf(posix.sockaddr.un, "path") + std.mem.indexOfScalar(u8, &self.un.path, 0).? + 1)
            else
                @sizeOf(posix.sockaddr),
            else => @sizeOf(posix.sockaddr),
        };
    }

    pub fn toIOAddress(self: Address) std.Io.net.IpAddress {
        return switch (self.any.family) {
            posix.AF.INET => {
                const bytes: *const [4]u8 = @ptrCast(&self.in.addr);
                return .{ .ip4 = .{ .bytes = bytes.*, .port = std.mem.bigToNative(u16, self.in.port) } };
            },
            posix.AF.INET6 => {
                // @ZIG016 I don't think this is correct
                const bytes: *const [16]u8 = @ptrCast(&self.in.addr);
                return .{ .ip6 = .{ .bytes = bytes.*, .port = std.mem.bigToNative(u16, self.in.port) } };
            },
            else => .{ .ip4 = .unspecified(0) },
        };
    }

    pub fn format(self: Address, w: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self.any.family) {
            posix.AF.INET => {
                const bytes: *const [4]u8 = @ptrCast(&self.in.addr);
                const port = std.mem.bigToNative(u16, self.in.port);
                try w.print("{d}.{d}.{d}.{d}:{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3], port });
            },
            posix.AF.INET6 => {
                const sa = self.in6;
                const port = std.mem.bigToNative(u16, sa.port);
                if (std.mem.eql(u8, sa.addr[0..12], &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff })) {
                    try w.print("[::ffff:{d}.{d}.{d}.{d}]:{d}", .{
                        sa.addr[12],
                        sa.addr[13],
                        sa.addr[14],
                        sa.addr[15],
                        port,
                    });
                    return;
                }
                const big_endian_parts = @as(*align(1) const [8]u16, @ptrCast(&sa.addr));

                const native_endian_parts = switch (builtin.target.cpu.arch.endian()) {
                    .big => big_endian_parts.*,
                    .little => blk: {
                        var buf: [8]u16 = undefined;
                        for (big_endian_parts, 0..) |part, i| {
                            buf[i] = std.mem.bigToNative(u16, part);
                        }
                        break :blk buf;
                    },
                };

                // Find the longest zero run
                var longest_start: usize = 8;
                var longest_len: usize = 0;
                var current_start: usize = 0;
                var current_len: usize = 0;

                for (native_endian_parts, 0..) |part, i| {
                    if (part == 0) {
                        if (current_len == 0) {
                            current_start = i;
                        }
                        current_len += 1;
                        if (current_len > longest_len) {
                            longest_start = current_start;
                            longest_len = current_len;
                        }
                    } else {
                        current_len = 0;
                    }
                }

                // Only compress if the longest zero run is 2 or more
                if (longest_len < 2) {
                    longest_start = 8;
                    longest_len = 0;
                }

                try w.writeAll("[");
                var i: usize = 0;
                var abbrv = false;
                while (i < native_endian_parts.len) : (i += 1) {
                    if (i == longest_start) {
                        // Emit "::" for the longest zero run
                        if (!abbrv) {
                            try w.writeAll(if (i == 0) "::" else ":");
                            abbrv = true;
                        }
                        i += longest_len - 1; // Skip the compressed range
                        continue;
                    }
                    if (abbrv) {
                        abbrv = false;
                    }
                    try w.print("{x}", .{native_endian_parts[i]});
                    if (i != native_endian_parts.len - 1) {
                        try w.writeAll(":");
                    }
                }
                try w.print("]:{}", .{port});
            },
            posix.AF.UNIX => try w.writeAll(std.mem.sliceTo(&self.un.path, 0)),
            else => unreachable,
        }
    }
};

pub fn listen(sock: socket_t, backlog: u31) !void {
    if (native_os == .windows) {
        const rc = windows.listen(sock, backlog);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable, // not initialized WSA
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEADDRINUSE => return error.AddressInUse,
                .WSAEISCONN => return error.AlreadyConnected,
                .WSAEINVAL => return error.SocketNotBound,
                .WSAEMFILE, .WSAENOBUFS => return error.SystemResources,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEOPNOTSUPP => return error.OperationNotSupported,
                .WSAEINPROGRESS => unreachable,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        const rc = system.listen(sock, backlog);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => unreachable,
            .NOTSOCK => return error.FileDescriptorNotASocket,
            .OPNOTSUPP => return error.OperationNotSupported,
            else => return error.Unexpected,
        }
    }
}

pub fn accept(
    /// This argument is a socket that has been created with `socket`, bound to a local address
    /// with `bind`, and is listening for connections after a `listen`.
    sock: socket_t,
    /// This argument is a pointer to a sockaddr structure.  This structure is filled in with  the
    /// address  of  the  peer  socket, as known to the communications layer.  The exact format of the
    /// address returned addr is determined by the socket's address  family  (see  `socket`  and  the
    /// respective  protocol  man  pages).
    addr: ?*sockaddr,
    /// This argument is a value-result argument: the caller must initialize it to contain  the
    /// size (in bytes) of the structure pointed to by addr; on return it will contain the actual size
    /// of the peer address.
    ///
    /// The returned address is truncated if the buffer provided is too small; in this  case,  `addr_size`
    /// will return a value greater than was supplied to the call.
    addr_size: ?*socklen_t,
    /// The following values can be bitwise ORed in flags to obtain different behavior:
    /// * `SOCK.NONBLOCK` - Set the `NONBLOCK` file status flag on the open file description (see `open`)
    ///   referred  to by the new file descriptor.  Using this flag saves extra calls to `fcntl` to achieve
    ///   the same result.
    /// * `CLOEXEC`  - Set the close-on-exec (`FD_CLOEXEC`) flag on the new file descriptor.   See  the
    ///   description  of the `CLOEXEC` flag in `open` for reasons why this may be useful.
    flags: u32,
) !socket_t {
    const have_accept4 = !(builtin.target.os.tag.isDarwin() or native_os == .windows or native_os == .haiku);
    std.debug.assert(0 == (flags & ~@as(u32, NONBLOCK | CLOEXEC))); // Unsupported flag(s)

    const accepted_sock: socket_t = while (true) {
        const rc = if (have_accept4)
            system.accept4(sock, addr, addr_size, flags)
        else if (native_os == .windows)
            windows.accept(sock, addr, addr_size)
        else
            system.accept(sock, addr, addr_size);

        if (native_os == .windows) {
            if (rc == windows.ws2_32.INVALID_SOCKET) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSANOTINITIALISED => unreachable, // not initialized WSA
                    .WSAECONNRESET => return error.ConnectionResetByPeer,
                    .WSAEFAULT => unreachable,
                    .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                    .WSAEINVAL => return error.SocketNotListening,
                    .WSAEMFILE => return error.ProcessFdQuotaExceeded,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENOBUFS => return error.FileDescriptorNotASocket,
                    .WSAEOPNOTSUPP => return error.OperationNotSupported,
                    .WSAEWOULDBLOCK => return error.WouldBlock,
                    else => |err| return windows.unexpectedWSAError(err),
                }
            } else {
                break rc;
            }
        } else {
            switch (posix.errno(rc)) {
                .SUCCESS => break @intCast(rc),
                .INTR => continue,
                .AGAIN => return error.WouldBlock,
                .BADF => {
                    // ZIG016 This is not right. If we hit this, it's always certainly
                    // an error - we're trying to read from a socket after it's been closed
                    // which is not safe. But, the code around this worked in 0.15 and I
                    // consider this entire 0.16 transition experimental.
                    return error.SocketNotListening;
                },
                .CONNABORTED => return error.ConnectionAborted,
                .FAULT => unreachable,
                .INVAL => return error.SocketNotListening,
                .NOTSOCK => unreachable,
                .MFILE => return error.ProcessFdQuotaExceeded,
                .NFILE => return error.SystemFdQuotaExceeded,
                .NOBUFS => return error.SystemResources,
                .NOMEM => return error.SystemResources,
                .OPNOTSUPP => unreachable,
                .PROTO => return error.ProtocolFailure,
                .PERM => return error.BlockedByFirewall,
                else => return error.Unexpected,
            }
        }
    };

    errdefer switch (native_os) {
        .windows => windows.closesocket(accepted_sock) catch unreachable,
        else => close(accepted_sock),
    };
    if (!have_accept4) {
        try setSockFlags(accepted_sock, flags);
    }
    return accepted_sock;
}

pub const iovec_const = posix.iovec_const;

pub fn write(fd: fd_t, bytes: []const u8) !usize {
    if (bytes.len == 0) return 0;
    if (native_os == .windows) {
        return windows.send(fd, bytes);
    }

    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => std.math.maxInt(i32),
        else => std.math.maxInt(isize),
    };
    while (true) {
        const rc = system.write(fd, bytes.ptr, @min(bytes.len, max_count));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => return error.InvalidArgument,
            .FAULT => unreachable,
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForWriting, // can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .ACCES => return error.AccessDenied,
            .PERM => return error.PermissionDenied,
            .PIPE => return error.BrokenPipe,
            .CONNRESET => return error.ConnectionResetByPeer,
            .BUSY => return error.DeviceBusy,
            .NXIO => return error.NoDevice,
            .MSGSIZE => return error.MessageTooBig,
            else => return error.Unexpected,
        }
    }
}

pub fn writev(fd: fd_t, iov: []const iovec_const) !usize {
    if (native_os == .windows) {
        // TODO improve this to use WriteFileScatter
        if (iov.len == 0) return 0;
        const first = iov[0];
        return write(fd, first.base[0..first.len]);
    }

    while (true) {
        const rc = system.writev(fd, iov.ptr, @min(iov.len, posix.IOV_MAX));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => return error.InvalidArgument,
            .FAULT => unreachable,
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForWriting, // Can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.PermissionDenied,
            .PIPE => return error.BrokenPipe,
            .CONNRESET => return error.ConnectionResetByPeer,
            .BUSY => return error.DeviceBusy,
            else => return error.Unexpected,
        }
    }
}

pub fn read(fd: fd_t, buf: []u8) !usize {
    if (buf.len == 0) return 0;
    if (native_os == .windows) {
        return windows.recv(fd, buf);
    }

    // Prevents EINVAL.
    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => std.math.maxInt(i32),
        else => std.math.maxInt(isize),
    };
    while (true) {
        const rc = system.read(fd, buf.ptr, @min(buf.len, max_count));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .CANCELED => return error.Canceled,
            .BADF => return error.NotOpenForReading, // Can be a race condition.
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            else => return error.Unexpected,
        }
    }
}

pub const ShutdownHow = enum { recv, send, both };

/// Shutdown socket send/receive operations
pub fn shutdown(sock: socket_t, how: ShutdownHow) !void {
    if (native_os == .windows) {
        const result = windows.ws2_32.shutdown(sock, switch (how) {
            .recv => windows.ws2_32.SD_RECEIVE,
            .send => windows.ws2_32.SD_SEND,
            .both => windows.ws2_32.SD_BOTH,
        });
        if (0 != result) switch (windows.ws2_32.WSAGetLastError()) {
            .WSAECONNABORTED => return error.ConnectionAborted,
            .WSAECONNRESET => return error.ConnectionResetByPeer,
            .WSAEINPROGRESS => return error.BlockingOperationInProgress,
            .WSAEINVAL => unreachable,
            .WSAENETDOWN => return error.NetworkSubsystemFailed,
            .WSAENOTCONN => return error.SocketNotConnected,
            .WSAENOTSOCK => unreachable,
            .WSANOTINITIALISED => unreachable,
            else => |err| return windows.unexpectedWSAError(err),
        };
    } else {
        const rc = system.shutdown(sock, switch (how) {
            .recv => posix.SHUT.RD,
            .send => posix.SHUT.WR,
            .both => posix.SHUT.RDWR,
        });
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            .BADF => unreachable,
            .INVAL => unreachable,
            .NOTCONN => return error.SocketNotConnected,
            .NOTSOCK => unreachable,
            .NOBUFS => return error.SystemResources,
            else => return error.Unexpected,
        }
    }
}

pub fn getsockname(sock: socket_t, addr: *sockaddr, addrlen: *socklen_t) !void {
    if (native_os == .windows) {
        const rc = windows.getsockname(sock, addr, addrlen);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEFAULT => unreachable, // addr or addrlen have invalid pointers or addrlen points to an incorrect value
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEINVAL => return error.SocketNotBound,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        const rc = system.getsockname(sock, addr, addrlen);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            .BADF => unreachable, // always a race condition
            .FAULT => unreachable,
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => return error.FileDescriptorNotASocket,
            .NOBUFS => return error.SystemResources,
            else => return error.Unexpected,
        }
    }
}

pub fn pipe() ![2]fd_t {
    var fds: [2]fd_t = undefined;
    switch (posix.errno(system.pipe(&fds))) {
        .SUCCESS => return fds,
        .INVAL => unreachable, // Invalid parameters to pipe()
        .FAULT => unreachable, // Invalid fds pointer
        .NFILE => return error.SystemFdQuotaExceeded,
        .MFILE => return error.ProcessFdQuotaExceeded,
        else => return error.Unexpected,
    }
}

pub fn pipe2(flags: O) ![2]fd_t {
    if (@TypeOf(system.pipe2) != void) {
        var fds: [2]fd_t = undefined;
        switch (posix.errno(system.pipe2(&fds, flags))) {
            .SUCCESS => return fds,
            .INVAL => unreachable, // Invalid flags
            .FAULT => unreachable, // Invalid fds pointer
            .NFILE => return error.SystemFdQuotaExceeded,
            .MFILE => return error.ProcessFdQuotaExceeded,
            else => return error.Unexpected,
        }
    }

    const fds: [2]fd_t = try pipe();
    errdefer {
        close(fds[0]);
        close(fds[1]);
    }

    // https://github.com/ziglang/zig/issues/18882
    if (@as(u32, @bitCast(flags)) == 0)
        return fds;

    // CLOEXEC is special, it's a file descriptor flag and must be set using
    // F.SETFD.
    if (flags.CLOEXEC) {
        for (fds) |fd| {
            switch (posix.errno(system.fcntl(fd, F.SETFD, @as(u32, system.FD_CLOEXEC)))) {
                .SUCCESS => {},
                .INVAL => unreachable, // Invalid flags
                .BADF => unreachable, // Always a race condition
                else => return error.Unexpected,
            }
        }
    }

    const new_flags: u32 = f: {
        var new_flags = flags;
        new_flags.CLOEXEC = false;
        break :f @bitCast(new_flags);
    };
    // Set every other flag affecting the file status using F.SETFL.
    if (new_flags != 0) {
        for (fds) |fd| {
            switch (posix.errno(system.fcntl(fd, F.SETFL, new_flags))) {
                .SUCCESS => {},
                .INVAL => unreachable, // Invalid flags
                .BADF => unreachable, // Always a race condition
                else => return error.Unexpected,
            }
        }
    }

    return fds;
}

pub fn kevent(
    kq: i32,
    changelist: []const Kevent,
    eventlist: []Kevent,
    timeout: ?*const timespec,
) !usize {
    while (true) {
        const rc = system.kevent(
            kq,
            changelist.ptr,
            std.math.cast(c_int, changelist.len) orelse return error.Overflow,
            eventlist.ptr,
            std.math.cast(c_int, eventlist.len) orelse return error.Overflow,
            timeout,
        );
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .ACCES => return error.AccessDenied,
            .FAULT => unreachable,
            .BADF => unreachable, // Always a race condition.
            .INTR => continue,
            .INVAL => unreachable,
            .NOENT => return error.EventNotFound,
            .NOMEM => return error.SystemResources,
            .SRCH => return error.ProcessNotFound,
            else => unreachable,
        }
    }
}

pub fn kqueue() !i32 {
    const rc = system.kqueue();
    switch (posix.errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        else => return error.Unexpected,
    }
}

pub fn eventfd(initval: u32, flags: u32) !i32 {
    const rc = system.eventfd(initval, flags);
    switch (posix.errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .INVAL => unreachable, // invalid parameters
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NODEV => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        else => return error.Unexpected,
    }
}

pub fn epoll_create1(flags: u32) !i32 {
    const rc = system.epoll_create1(flags);
    switch (posix.errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .INVAL => unreachable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        else => return error.Unexpected,
    }
}

pub fn epoll_ctl(epfd: i32, op: u32, fd: i32, event: ?*system.epoll_event) !void {
    const rc = system.epoll_ctl(epfd, op, fd, event);
    switch (posix.errno(rc)) {
        .SUCCESS => return,
        .BADF => unreachable, // always a race condition if this happens
        .EXIST => return error.FileDescriptorAlreadyPresentInSet,
        .INVAL => unreachable,
        .LOOP => return error.OperationCausesCircularLoop,
        .NOENT => return error.FileDescriptorNotRegistered,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.UserResourceLimitReached,
        .PERM => return error.FileDescriptorIncompatibleWithEpoll,
        else => return error.Unexpected,
    }
}

/// Waits for an I/O event on an epoll file descriptor.
/// Returns the number of file descriptors ready for the requested I/O,
/// or zero if no file descriptor became ready during the requested timeout milliseconds.
pub fn epoll_wait(epfd: i32, events: []system.epoll_event, timeout: i32) usize {
    while (true) {
        // TODO get rid of the @intCast
        const rc = system.epoll_wait(epfd, events.ptr, @intCast(events.len), timeout);
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .BADF => unreachable,
            .FAULT => unreachable,
            .INVAL => unreachable,
            else => unreachable,
        }
    }
}
