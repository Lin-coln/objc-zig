const std = @import("std");
const utils = @import("utils.zig");
const toSpreadedFn = @import("../../src/utils/root.zig").toSpreadedFn;

pub fn makeMethod(
    comptime Receiver: ?type,
    comptime call: anytype,
    comptime name: [:0]const u8,
    comptime Shape: type,
) type {
    const Resolved = resolveFromShape(Shape);

    const Args = if (Receiver) |R| @Tuple(&([_]type{R} ++ Resolved.types)) else @Tuple(&Resolved.types);

    return struct {
        pub const function = toSpreadedFn(invoke, .{ .cc = Resolved.cc });
        fn invoke(args: Args) Resolved.Return {
            if (comptime Receiver != null) {
                const CallArgs = @Tuple(&Resolved.types);
                var call_args: CallArgs = undefined;
                inline for (0..Resolved.types.len) |i| {
                    call_args[i] = args[i + 1];
                }
                return call(args[0], Resolved.Return, name, call_args);
            } else {
                return call(Resolved.Return, name, args);
            }
        }
    };
}

pub fn resolveFromShape(comptime Shape: type) type {
    const info = utils.resolveFnInfo(Shape, .{});

    comptime var param_types: [info.param_types.len]type = undefined;
    inline for (info.param_types, 0..) |p_type, i| {
        param_types[i] = p_type.?;
    }
    const resolved_types = param_types;

    return struct {
        pub const types = resolved_types;
        pub const cc = info.attrs.@"callconv";
        pub const Return = info.return_type.?;
    };
}

test "of: Shape preserves parameter types and contextual initialization" {
    const Method = @import("root.zig").Method;
    const Payload = extern struct { value: c_ulong = 3 };
    const Receiver = struct { base: c_ulong };
    const ClassHelper = struct {
        var last_name: []const u8 = "";

        pub fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            if (Return != c_ulong) @compileError("unexpected return type");
            last_name = name;
            return args[0] + args[1].value;
        }
    };
    const ObjectHelper = struct {
        var last_name: []const u8 = "";

        pub fn call(self: *Receiver, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            if (Return != c_ulong) @compileError("unexpected return type");
            last_name = name;
            return self.base + args[0] + args[1].value;
        }
    };
    const Shape = fn (c_ulong, Payload) c_ulong;
    const class_method = Method(Receiver, ClassHelper).of("value:payload:", Shape);
    const object_method = Method(Receiver, ObjectHelper).of("value:payload:", Shape);
    const CShape = fn (c_ulong, Payload) callconv(.c) c_ulong;
    const c_method = Method(Receiver, ClassHelper).of("value:payload:", CShape);
    try std.testing.expect(@TypeOf(class_method) == Shape);
    try std.testing.expect(@TypeOf(object_method) == fn (*Receiver, c_ulong, Payload) c_ulong);
    try std.testing.expect(@TypeOf(c_method) == CShape);

    const value: c_int = 4;
    try std.testing.expectEqual(@as(c_ulong, 7), class_method(value, .{}));
    try std.testing.expectEqual(@as(c_ulong, 9), class_method(value, .{ .value = 5 }));
    try std.testing.expectEqual(@as(c_ulong, 9), c_method(value, .{ .value = 5 }));
    try std.testing.expectEqualStrings("value:payload:", ClassHelper.last_name);
    var receiver: Receiver = .{ .base = 10 };
    try std.testing.expectEqual(@as(c_ulong, 17), object_method(&receiver, value, .{}));
    try std.testing.expectEqual(@as(c_ulong, 19), object_method(&receiver, value, .{ .value = 5 }));
    try std.testing.expectEqualStrings("value:payload:", ObjectHelper.last_name);
}

test "of: return types and pointer nullability are preserved" {
    const Method = @import("root.zig").Method;
    const rt = @import("../../src/rt/root.zig");
    const Helper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            if (Return != @TypeOf(args[0])) @compileError("unexpected message return type");
            return args[0];
        }
    };
    var value: u8 = 42;
    const m = Method(rt.Object, Helper);
    const cases = .{
        @as(*u8, &value),
        @as(*const u8, &value),
        @as([*]u8, @ptrCast(&value)),
        @as([*:0]const u8, "hello"),
        @as(?*u8, null),
        @as([*c]u8, null),
        @as(*allowzero u8, @ptrFromInt(0)),
        @as(usize, 42),
        false,
    };
    inline for (cases) |expected| {
        const T = @TypeOf(expected);
        const Shape = fn (T) T;
        const bound = m.of("value", Shape);
        try std.testing.expect(@TypeOf(bound) == Shape);
        try std.testing.expectEqual(expected, bound(expected));
    }
}
