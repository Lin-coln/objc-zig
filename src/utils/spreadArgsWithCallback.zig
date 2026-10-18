const std = @import("std");

/// Expands tuple arguments between a generic context and a comptime callback.
/// `Callback(Context)` supplies the callback function type, and `handler` receives
/// `(ctx, args, callback)`. Supports zero to twelve tuple elements.
pub fn spreadArgsWithCallback(
    comptime Args: type,
    comptime Callback: anytype,
    comptime handler: anytype,
) @TypeOf(Wrapper(void, Args, Callback, handler).call) {
    return Wrapper(void, Args, Callback, handler).call;
}

/// Expands tuple arguments after a receiver and context, followed by a comptime callback.
/// The handler receives `(receiver, ctx, args, callback)`. Supports zero to twelve tuple elements.
pub fn spreadArgsWithReceiverAndCallback(
    comptime Receiver: type,
    comptime Args: type,
    comptime Callback: anytype,
    comptime handler: anytype,
) @TypeOf(Wrapper(Receiver, Args, Callback, handler).callWithReceiver) {
    return Wrapper(Receiver, Args, Callback, handler).callWithReceiver;
}

fn Wrapper(comptime Receiver: type, comptime Args: type, comptime Callback: anytype, comptime handler: anytype) type {
    if (@typeInfo(Args) != .@"struct" or !@typeInfo(Args).@"struct".is_tuple)
        @compileError("spreadArgsWithCallback Args must be a tuple type");
    const params = @typeInfo(Args).@"struct".field_types;
    if (params.len > 12)
        @compileError("spreadArgsWithCallback supports at most 12 tuple elements");
    const Return = @typeInfo(@TypeOf(handler)).@"fn".return_type orelse
        @compileError("spreadArgsWithCallback handler must have a known return type");

    return switch (params.len) {
        0 => struct {
            pub fn call(ctx: anytype, comptime callback: *const Callback(@TypeOf(ctx))) Return {
                return handler(ctx, .{}, callback);
            }

            pub fn callWithReceiver(receiver: Receiver, ctx: anytype, comptime callback: *const Callback(@TypeOf(ctx))) Return {
                return handler(receiver, ctx, .{}, callback);
            }
        },
        1 => struct {
            pub fn call(ctx: anytype, arg0: params[0], comptime callback: *const Callback(@TypeOf(ctx))) Return {
                return handler(ctx, .{arg0}, callback);
            }

            pub fn callWithReceiver(receiver: Receiver, ctx: anytype, arg0: params[0], comptime callback: *const Callback(@TypeOf(ctx))) Return {
                return handler(receiver, ctx, .{arg0}, callback);
            }
        },
        2 => struct {
            pub fn call(ctx: anytype, arg0: params[0], arg1: params[1], comptime callback: *const Callback(@TypeOf(ctx))) Return {
                return handler(ctx, .{ arg0, arg1 }, callback);
            }

            pub fn callWithReceiver(receiver: Receiver, ctx: anytype, arg0: params[0], arg1: params[1], comptime callback: *const Callback(@TypeOf(ctx))) Return {
                return handler(receiver, ctx, .{ arg0, arg1 }, callback);
            }
        },
        3 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2 }, callback);
            }
        },
        4 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3 }, callback);
            }
        },
        5 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4 }, callback);
            }
        },
        6 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5 }, callback);
            }
        },
        7 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6 }, callback);
            }
        },
        8 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7 }, callback);
            }
        },
        9 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 }, callback);
            }
        },
        10 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                arg9: params[9],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                arg9: params[9],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 }, callback);
            }
        },
        11 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                arg9: params[9],
                arg10: params[10],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                arg9: params[9],
                arg10: params[10],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 }, callback);
            }
        },
        12 => struct {
            pub fn call(
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                arg9: params[9],
                arg10: params[10],
                arg11: params[11],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 }, callback);
            }

            pub fn callWithReceiver(
                receiver: Receiver,
                ctx: anytype,
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
                arg9: params[9],
                arg10: params[10],
                arg11: params[11],
                comptime callback: *const Callback(@TypeOf(ctx)),
            ) Return {
                return handler(receiver, ctx, .{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 }, callback);
            }
        },
        else => unreachable,
    };
}

test "spreadArgsWithCallback: parameter order and context-dependent callback" {
    inline for (0..13) |count| {
        const Args = @Tuple(&@as([count]type, @splat(i32)));
        const Handler = struct {
            fn Callback(comptime Context: type) type {
                return fn (Context, i32) i32;
            }

            fn invoke(ctx: anytype, args: Args, comptime callback: *const Callback(@TypeOf(ctx))) i32 {
                var sum: i32 = 0;
                inline for (args, 0..) |value, i| sum += value * @as(i32, @intCast(i + 1));
                return callback(ctx, sum);
            }

            fn complete(ctx: *const i32, sum: i32) i32 {
                return ctx.* + sum;
            }
        };
        const function = spreadArgsWithCallback(Args, Handler.Callback, Handler.invoke);
        const ctx: i32 = 7;
        var args: Args = undefined;
        var expected: i32 = ctx;
        inline for (0..count) |i| {
            const value: i32 = @intCast(i + 1);
            args[i] = value;
            expected += value * value;
        }
        try std.testing.expectEqual(expected, @call(.auto, function, .{&ctx} ++ args ++ .{Handler.complete}));
    }
}

test "spreadArgsWithReceiverAndCallback: receiver, context and argument order" {
    inline for (0..13) |count| {
        const Args = @Tuple(&@as([count]type, @splat(i32)));
        const Handler = struct {
            fn Callback(comptime Context: type) type {
                return fn (Context, i32) i32;
            }

            fn invoke(receiver: *const i32, ctx: anytype, args: Args, comptime callback: *const Callback(@TypeOf(ctx))) i32 {
                var sum: i32 = receiver.*;
                inline for (args, 0..) |value, i| sum += value * @as(i32, @intCast(i + 1));
                return callback(ctx, sum);
            }

            fn complete(ctx: *const i32, sum: i32) i32 {
                return ctx.* + sum;
            }
        };
        const function = spreadArgsWithReceiverAndCallback(*const i32, Args, Handler.Callback, Handler.invoke);
        const ctx: i32 = 7;
        const receiver: i32 = 11;
        var args: Args = undefined;
        var expected: i32 = ctx + receiver;
        inline for (0..count) |i| {
            const value: i32 = @intCast(i + 1);
            args[i] = value;
            expected += value * value;
        }
        try std.testing.expectEqual(expected, @call(.auto, function, .{ &receiver, &ctx } ++ args ++ .{Handler.complete}));
    }
}
