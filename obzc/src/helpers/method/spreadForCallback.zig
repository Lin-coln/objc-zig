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
        5 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4 }, cb);
            }
        },
        6 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5 }, cb);
            }
        },
        7 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6 }, cb);
            }
        },
        8 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7 }, cb);
            }
        },
        9 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8 }, cb);
            }
        },
        10 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9 }, cb);
            }
        },
        11 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 }, cb);
            }
        },
        12 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 }, cb);
            }
        },
        13 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 }, cb);
            }
        },
        14 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], a13: f[13], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], a13: f[13], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 }, cb);
            }
        },
        15 => struct {
            fn c(ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], a13: f[13], a14: f[14], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14 }, cb);
            }
            fn rc(r: Receiver.?, ctx: anytype, a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], a13: f[13], a14: f[14], comptime cb: *const Callback(@TypeOf(ctx))) callconv(cc) R {
                return handle(r, ctx, .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14 }, cb);
            }
        },
        else => @compileError("withCallback supports at most 15 method arguments"),
    };

    return struct {
        const c = if (Receiver == null) Static.c else Static.rc;
    };
}

test "toSpreadFn forwards zero through fifteen typed arguments with and without a receiver" {
    @setEvalBranchQuota(10_000);
    const State = struct { result: i32 = -1, calls: usize = 0 };
    const Receiver = struct { base: i32 };
    const Arg = struct {
        fn of(comptime index: usize) type {
            return struct {
                value: i32,
                pub const position = index;
            };
        }
    };
    comptime {
        if (Arg.of(0) == Arg.of(1)) @compileError("argument types must differ by position");
    }
    const Callback = struct {
        fn Type(comptime Context: type) type {
            return fn (Context, i32) void;
        }
        fn record(state: *State, result: i32) void {
            state.calls += 1;
            state.result = result;
        }
    };

    inline for (0..16) |count| {
        comptime var types: [count]type = undefined;
        inline for (0..count) |i| types[i] = Arg.of(i);
        const Args = @Tuple(&types);
        const Handle = struct {
            fn weighted(args: Args) i32 {
                var result: i32 = 0;
                inline for (args, 0..) |arg, i| {
                    if (@TypeOf(arg) != Arg.of(i)) @compileError("argument type changed during spreading");
                    result += arg.value * @as(i32, @intCast(i + 1));
                }
                return result;
            }
            fn class(ctx: anytype, args: Args, comptime cb: *const Callback.Type(@TypeOf(ctx))) void {
                cb(ctx, weighted(args));
            }
            fn instance(receiver: *Receiver, ctx: anytype, args: Args, comptime cb: *const Callback.Type(@TypeOf(ctx))) void {
                cb(ctx, receiver.base + weighted(args));
            }
        };
        const class_fn = toSpreadFn(Handle.class, .{}, Callback.Type);
        const instance_fn = toSpreadFn(Handle.instance, .{}, Callback.Type);

        var args: Args = undefined;
        var expected: i32 = 0;
        inline for (0..count) |i| {
            args[i] = .{ .value = @intCast(i + 1) };
            expected += @as(i32, @intCast((i + 1) * (i + 1)));
        }

        var state: State = .{};
        @call(.auto, class_fn, .{&state} ++ args ++ .{&Callback.record});
        try std.testing.expectEqual(@as(usize, 1), state.calls);
        try std.testing.expectEqual(expected, state.result);

        var receiver: Receiver = .{ .base = 100 };
        @call(.auto, instance_fn, .{ &receiver, &state } ++ args ++ .{&Callback.record});
        try std.testing.expectEqual(@as(usize, 2), state.calls);
        try std.testing.expectEqual(100 + expected, state.result);
    }
}
