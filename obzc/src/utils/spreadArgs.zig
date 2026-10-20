const std = @import("std");

/// Adapts a single-tuple handler to separate parameters, preserving their order.
/// Returns a function value for both fixed and generic handlers.
/// Fixed tuple handlers retain their parameter types and requested calling convention.
/// Generic tuple handlers require an arity and use an inline `anytype` entry point.
/// Inlining preserves values known at the call site, including constants and comptime callbacks.
/// Generic arguments retain their inferred types; use a fixed tuple for contextual parameter types.
/// Supports zero to fifteen parameters.
pub fn spreadArgs(
    comptime handler: anytype,
    comptime options: struct {
        arity: ?usize = null,
        convention: std.lang.CallingConvention = .auto,
    },
) FunctionFromTupleHandler(handler, options) {
    const fn_info = @typeInfo(@TypeOf(handler)).@"fn";
    const arity = options.arity orelse @typeInfo(fn_info.param_types[0].?).@"struct".field_types.len;
    const Static = Functions(handler, arity, options.convention);
    return if (fn_info.is_generic) Static.generic else Static.call;
}

fn FunctionFromTupleHandler(comptime handler: anytype, comptime options: anytype) type {
    const fn_info = switch (@typeInfo(@TypeOf(handler))) {
        .@"fn" => |info| info,
        else => @compileError("spreadArgs handler must be a function"),
    };
    if (fn_info.attrs.varargs or fn_info.param_types.len != 1)
        @compileError("spreadArgs handler must take exactly one tuple parameter");
    if (fn_info.is_generic) {
        if (fn_info.param_types[0] != null)
            @compileError("spreadArgs generic handler must take an anytype tuple parameter");
        const arity = options.arity orelse @compileError("spreadArgs generic handler requires arity");
        if (arity > 15)
            @compileError("spreadArgs supports at most 15 parameters");
        if (options.convention != .auto)
            @compileError("spreadArgs generic handler requires the auto calling convention");
        return @TypeOf(Functions(handler, arity, .auto).generic);
    }
    const tuple_info = switch (@typeInfo(fn_info.param_types[0].?)) {
        .@"struct" => |info| info,
        else => @compileError("spreadArgs handler parameter must be a tuple"),
    };
    if (!tuple_info.is_tuple)
        @compileError("spreadArgs handler parameter must be a tuple");
    if (tuple_info.field_types.len > 15)
        @compileError("spreadArgs supports at most 15 parameters");
    if (options.arity) |arity| {
        if (arity != tuple_info.field_types.len)
            @compileError("spreadArgs arity must match the handler tuple length");
    }
    return @Fn(tuple_info.field_types, &@splat(.{}), fn_info.return_type.?, .{ .@"callconv" = options.convention });
}

fn Functions(comptime handler: anytype, comptime arity: usize, comptime convention: std.lang.CallingConvention) type {
    const fn_info = @typeInfo(@TypeOf(handler)).@"fn";
    const params: []const type = if (fn_info.is_generic) &.{} else @typeInfo(fn_info.param_types[0].?).@"struct".field_types;
    return switch (arity) {
        0 => struct {
            fn call() callconv(convention) fn_info.return_type.? {
                return handler(.{});
            }

            inline fn generic() @TypeOf(handler(.{})) {
                return handler(.{});
            }
        },
        1 => struct {
            fn call(arg0: params[0]) callconv(convention) fn_info.return_type.? {
                return handler(.{arg0});
            }

            inline fn generic(arg0: anytype) @TypeOf(handler(.{arg0})) {
                return handler(.{arg0});
            }
        },
        2 => struct {
            fn call(arg0: params[0], arg1: params[1]) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1 });
            }

            inline fn generic(arg0: anytype, arg1: anytype) @TypeOf(handler(.{ arg0, arg1 })) {
                return handler(.{ arg0, arg1 });
            }
        },
        3 => struct {
            fn call(arg0: params[0], arg1: params[1], arg2: params[2]) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2 });
            }

            inline fn generic(arg0: anytype, arg1: anytype, arg2: anytype) @TypeOf(handler(.{ arg0, arg1, arg2 })) {
                return handler(.{ arg0, arg1, arg2 });
            }
        },
        4 => struct {
            fn call(
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3 })) {
                return handler(.{ arg0, arg1, arg2, arg3 });
            }
        },
        5 => struct {
            fn call(
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4 });
            }
        },
        6 => struct {
            fn call(
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5 });
            }
        },
        7 => struct {
            fn call(
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6 });
            }
        },
        8 => struct {
            fn call(
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7 });
            }
        },
        9 => struct {
            fn call(
                arg0: params[0],
                arg1: params[1],
                arg2: params[2],
                arg3: params[3],
                arg4: params[4],
                arg5: params[5],
                arg6: params[6],
                arg7: params[7],
                arg8: params[8],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
                arg8: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 });
            }
        },
        10 => struct {
            fn call(
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
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
                arg8: anytype,
                arg9: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 });
            }
        },
        11 => struct {
            fn call(
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
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
                arg8: anytype,
                arg9: anytype,
                arg10: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 });
            }
        },
        12 => struct {
            fn call(
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
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
                arg8: anytype,
                arg9: anytype,
                arg10: anytype,
                arg11: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 });
            }
        },
        13 => struct {
            fn call(
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
                arg12: params[12],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
                arg8: anytype,
                arg9: anytype,
                arg10: anytype,
                arg11: anytype,
                arg12: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12 });
            }
        },
        14 => struct {
            fn call(
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
                arg12: params[12],
                arg13: params[13],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
                arg8: anytype,
                arg9: anytype,
                arg10: anytype,
                arg11: anytype,
                arg12: anytype,
                arg13: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13 });
            }
        },
        15 => struct {
            fn call(
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
                arg12: params[12],
                arg13: params[13],
                arg14: params[14],
            ) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 });
            }

            inline fn generic(
                arg0: anytype,
                arg1: anytype,
                arg2: anytype,
                arg3: anytype,
                arg4: anytype,
                arg5: anytype,
                arg6: anytype,
                arg7: anytype,
                arg8: anytype,
                arg9: anytype,
                arg10: anytype,
                arg11: anytype,
                arg12: anytype,
                arg13: anytype,
                arg14: anytype,
            ) @TypeOf(handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 })) {
                return handler(.{ arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 });
            }
        },
        else => unreachable,
    };
}

test "spreadArgs: zero through fifteen parameters preserve order" {
    inline for (0..16) |count| {
        const Args = @Tuple(&@as([count]type, @splat(i32)));
        const Handler = struct {
            fn call(args: Args) i32 {
                var result: i32 = 7;
                inline for (args, 0..) |value, i| result += value * @as(i32, @intCast(i + 1));
                return result;
            }
        };
        const function = spreadArgs(Handler.call, .{ .convention = .c });
        var args: Args = undefined;
        var expected: i32 = 7;
        inline for (0..count) |i| {
            const value: i32 = @intCast(i + 1);
            args[i] = value;
            expected += value * value;
        }
        try std.testing.expectEqual(expected, @call(.auto, function, args));
    }
}

test "spreadArgs: mixed parameter types, struct return and calling convention" {
    const Result = extern struct { value: f64 };
    const Handler = struct {
        fn call(args: @Tuple(&.{ *const i32, f64, u8 })) Result {
            return .{ .value = @as(f64, @floatFromInt(args[0].*)) * args[1] + @as(f64, @floatFromInt(args[2])) };
        }
    };
    const value: i32 = 7;
    const function = spreadArgs(Handler.call, .{ .convention = .c });
    try std.testing.expect(@TypeOf(function) == fn (*const i32, f64, u8) callconv(.c) Result);
    try std.testing.expectEqual(17.0, function(&value, 2.0, 3).value);
    const automatic = spreadArgs(Handler.call, .{});
    try std.testing.expect(@TypeOf(automatic) == fn (*const i32, f64, u8) Result);
    try std.testing.expectEqual(17.0, automatic(&value, 2.0, 3).value);
}

test "spreadArgs: generic parameters preserve runtime values and function identity" {
    const Handler = struct {
        fn increment(value: i32) i32 {
            return value + 1;
        }

        fn decrement(value: i32) i32 {
            return value - 1;
        }

        fn call(args: anytype) @TypeOf(args[2](args[0].* + args[1])) {
            return args[2](args[0].* + args[1]);
        }
    };
    var value: i32 = 7;
    const function = spreadArgs(Handler.call, .{ .arity = 3 });
    try std.testing.expectEqual(13, function(&value, @as(i32, 5), Handler.increment));
    value = 10;
    try std.testing.expectEqual(16, function(&value, @as(i32, 5), Handler.increment));
    try std.testing.expectEqual(14, function(&value, @as(i32, 5), Handler.decrement));
}

test "spreadArgs: generic return type follows its arguments" {
    const Handler = struct {
        fn call(args: anytype) args[0] {
            return @as(args[0], args[1]);
        }
    };
    const function = spreadArgs(Handler.call, .{ .arity = 2 });
    try std.testing.expect(@TypeOf(function(u8, 7)) == u8);
    try std.testing.expect(@TypeOf(function(f64, 2.5)) == f64);
    try std.testing.expectEqual(7, function(u8, 7));
    try std.testing.expectEqual(2.5, function(f64, 2.5));
    try std.testing.expectError(error.Rejected, function(error{Rejected}!u8, error.Rejected));
}

test "spreadArgs: generic zero through fifteen parameters preserve order" {
    const Handler = struct {
        fn call(args: anytype) i32 {
            var result: i32 = 7;
            inline for (args, 0..) |value, i| result += value * @as(i32, @intCast(i + 1));
            return result;
        }
    };
    inline for (0..16) |count| {
        const function = spreadArgs(Handler.call, .{ .arity = count });
        var args: @Tuple(&@as([count]type, @splat(i32))) = undefined;
        var expected: i32 = 7;
        inline for (0..count) |i| {
            const value: i32 = @intCast(i + 1);
            args[i] = value;
            expected += value * value;
        }
        try std.testing.expectEqual(expected, @call(.auto, function, args));
    }
}

test "spreadArgs: generic forwarding preserves constants and comptime function pointers" {
    const Handler = struct {
        fn add(context: *c_ulong, value: c_ulong) c_ulong {
            return context.* + value;
        }

        fn apply(context: *c_ulong, value: c_ulong, comptime function: *const fn (*c_ulong, c_ulong) c_ulong) c_ulong {
            return function(context, value);
        }

        fn call(args: anytype) c_ulong {
            return apply(args[0], args[1], args[2]);
        }
    };
    const function = spreadArgs(Handler.call, .{ .arity = 3 });
    var context: c_ulong = 7;
    const constant: c_int = 5;
    try std.testing.expectEqual(@as(c_ulong, 12), function(&context, constant, &Handler.add));
    context += 1;
    try std.testing.expectEqual(@as(c_ulong, 16), function(&context, context, Handler.add));
}
