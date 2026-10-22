const std = @import("std");

const SpreadOptions = struct {
    cc: ?std.lang.CallingConvention = null,
};

pub fn toSpreadFn(
    comptime handle: anytype,
    comptime opts: SpreadOptions,
    comptime Callback: anytype,
) @TypeOf(toSpreaded(handle, opts, Callback).c) {
    return toSpreaded(handle, opts, Callback).c;
}

fn toSpreaded(
    comptime handle: anytype,
    comptime opts: SpreadOptions,
    comptime Callback: anytype,
) type {
    const info = @typeInfo(@TypeOf(handle)).@"fn";

    if (info.attrs.varargs)
        @compileError("Variadic functions are not supported");

    const Receiver, const Args = blk: {
        if (info.param_attrs.len == 3) {
            break :blk .{ @as(?type, null), info.param_types[1].? };
        } else {
            break :blk .{ info.param_types[0], info.param_types[2].? };
        }
    };

    const R = info.return_type.?;
    const cc = opts.cc orelse info.attrs.@"callconv";
    const f = @typeInfo(Args).@"struct".field_types;

    const Static = switch (f.len) {
        0 => struct {
            fn c(ctx: anytype, comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{}, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{}, cb);
            }
        },
        1 => struct {
            fn c(ctx: anytype, a0: f[0], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{a0}, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{a0}, cb);
            }
        },
        2 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1 }, cb);
            }
        },
        3 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2 }, cb);
            }
        },
        4 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3 }, cb);
            }
        },
        else => @compileError("Unsupported argument count"),
    };

    return struct {
        const c = if (Receiver == null) Static.c else Static.rc;
    };
}
