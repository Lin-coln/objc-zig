const std = @import("std");
const utils = @import("../utils/root.zig");

/// Prepends argument types to a fixed function signature, preserving its return type and attributes.
pub fn prependArgs(comptime Shape: type, comptime Args: []const type) type {
    const fn_info = switch (@typeInfo(Shape)) {
        .@"fn" => |info| info,
        else => @compileError("prependArgs Shape must be a function type"),
    };
    if (fn_info.is_generic or fn_info.attrs.varargs)
        @compileError("prependArgs Shape must have fixed, non-generic parameters");

    var params: [Args.len + fn_info.param_types.len]type = undefined;
    @memcpy(params[0..Args.len], Args);
    for (fn_info.param_types, Args.len..) |Param, i| params[i] = Param.?;
    var attrs: [params.len]std.lang.Type.Fn.ParamAttributes = @splat(.{});
    @memcpy(attrs[Args.len..], fn_info.param_attrs);
    return @Fn(&params, &attrs, fn_info.return_type.?, fn_info.attrs);
}

/// Binds a selector to `Shape` using the supplied message sender.
/// The sender receives `(Return, name, args)` and handles the target itself.
/// Non-null one/many pointer returns are received as optional pointers and unwrapped with `.?`.
pub fn method(
    comptime name: [:0]const u8,
    comptime Shape: type,
    comptime sender: anytype,
) *const Shape {
    const fn_info = switch (@typeInfo(Shape)) {
        .@"fn" => |info| info,
        else => @compileError("method Shape must be a function type"),
    };
    if (fn_info.is_generic or fn_info.attrs.varargs)
        @compileError("method Shape must have fixed, non-generic parameters");

    const Return = fn_info.return_type.?;
    const Static = struct {
        fn call(args: std.meta.ArgsTuple(Shape)) Return {
            switch (@typeInfo(Return)) {
                .pointer => |info| {
                    if ((info.size == .one or info.size == .many) and !info.attrs.@"allowzero")
                        return sender(?Return, name, args).?;
                },
                else => {},
            }

            return sender(Return, name, args);
        }
    };

    return utils.spreadArgs(Static.call, fn_info.attrs.@"callconv");
}

test "method: non-null pointers use nullable message returns" {
    const Sender = struct {
        fn send(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            if (Return != @TypeOf(args[0])) @compileError("unexpected message return type");
            return args[0];
        }
    };
    var value: u8 = 42;
    const cases = .{
        .{ *u8, @as(?*u8, &value) },
        .{ *const u8, @as(?*const u8, &value) },
        .{ [*]u8, @as(?[*]u8, @ptrCast(&value)) },
        .{ [*:0]const u8, @as(?[*:0]const u8, "hello") },
    };
    inline for (cases) |case| {
        const Shape = fn (@TypeOf(case[1])) case[0];
        const bound = method("pointer", Shape, Sender.send);
        try std.testing.expectEqual(case[1].?, bound(case[1]));
    }
}

test "method: nullable, zero-allowing and scalar returns are preserved" {
    const Sender = struct {
        fn send(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            if (Return != @TypeOf(args[0])) @compileError("unexpected message return type");
            return args[0];
        }
    };
    const cases = .{
        @as(?*u8, null),
        @as([*c]u8, null),
        @as(*allowzero u8, @ptrFromInt(0)),
        @as(usize, 42),
        false,
    };
    inline for (cases) |value| {
        const T = @TypeOf(value);
        const bound = method("value", fn (T) T, Sender.send);
        try std.testing.expectEqual(value, bound(value));
    }
}

test "prependArgs: parameter order, return type and function attributes" {
    const Shape = fn (noalias *i32, f64) callconv(.c) usize;
    try std.testing.expect(prependArgs(Shape, &.{}) == Shape);
    const Prepended = prependArgs(Shape, &.{ *anyopaque, u8 });
    try std.testing.expect(Prepended == fn (*anyopaque, u8, noalias *i32, f64) callconv(.c) usize);
    try std.testing.expect(@typeInfo(Prepended).@"fn".param_attrs[2].@"noalias");
}
