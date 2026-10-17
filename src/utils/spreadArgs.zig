const std = @import("std");

/// Adapts a single-tuple handler to a function taking the tuple elements as separate parameters.
/// Supports zero to thirteen parameters, using the requested calling convention.
pub fn spreadArgs(
    comptime handler: anytype,
    comptime convention: std.lang.CallingConvention,
) FunctionFromTupleHandler(@TypeOf(handler), convention) {
    const Handler = @TypeOf(handler);
    const fn_info = @typeInfo(Handler).@"fn";
    const params = @typeInfo(fn_info.param_types[0].?).@"struct".field_types;
    const Static = switch (params.len) {
        0 => struct {
            fn call() callconv(convention) fn_info.return_type.? {
                return handler(.{});
            }
        },
        1 => struct {
            fn call(arg0: params[0]) callconv(convention) fn_info.return_type.? {
                return handler(.{arg0});
            }
        },
        2 => struct {
            fn call(arg0: params[0], arg1: params[1]) callconv(convention) fn_info.return_type.? {
                return handler(.{ arg0, arg1 });
            }
        },
        3 => struct {
            fn call(arg0: params[0], arg1: params[1], arg2: params[2]) callconv(convention) fn_info.return_type.? {
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
        },
        else => unreachable,
    };
    return &Static.call;
}

fn FunctionFromTupleHandler(comptime Handler: type, comptime convention: std.lang.CallingConvention) type {
    const fn_info = switch (@typeInfo(Handler)) {
        .@"fn" => |info| info,
        else => @compileError("spreadArgs handler must be a function"),
    };
    if (fn_info.is_generic or fn_info.attrs.varargs or fn_info.param_types.len != 1)
        @compileError("spreadArgs handler must take exactly one fixed tuple parameter");
    const tuple_info = switch (@typeInfo(fn_info.param_types[0].?)) {
        .@"struct" => |info| info,
        else => @compileError("spreadArgs handler parameter must be a tuple"),
    };
    if (!tuple_info.is_tuple)
        @compileError("spreadArgs handler parameter must be a tuple");
    if (tuple_info.field_types.len > 13)
        @compileError("spreadArgs supports at most 13 parameters");
    return *const @Fn(tuple_info.field_types, &@splat(.{}), fn_info.return_type.?, .{ .@"callconv" = convention });
}

test "spreadArgs: zero through thirteen parameters preserve order" {
    inline for (0..14) |count| {
        const Args = @Tuple(&@as([count]type, @splat(i32)));
        const Handler = struct {
            fn call(args: Args) i32 {
                var result: i32 = 7;
                inline for (args, 0..) |value, i| result += value * @as(i32, @intCast(i + 1));
                return result;
            }
        };
        const function = spreadArgs(Handler.call, .c);
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
    const function = spreadArgs(Handler.call, .c);
    try std.testing.expect(@TypeOf(function) == *const fn (*const i32, f64, u8) callconv(.c) Result);
    try std.testing.expectEqual(17.0, function(&value, 2.0, 3).value);
    const automatic = spreadArgs(Handler.call, .auto);
    try std.testing.expect(@TypeOf(automatic) == *const fn (*const i32, f64, u8) Result);
    try std.testing.expectEqual(17.0, automatic(&value, 2.0, 3).value);
}
