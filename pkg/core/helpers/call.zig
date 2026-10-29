const std = @import("std");
const ffi = @import("../ffi/root.zig");

/// Calls a method, converting top-level bool arguments and returns through BOOL.
pub fn call(receiver: anytype, comptime Return: type, name: [:0]const u8, args: anytype) Return {
    const fields = @typeInfo(@TypeOf(args)).@"struct".field_types;
    comptime var types: [fields.len]type = undefined;
    inline for (fields, 0..) |Field, i| types[i] = ffi.cast.type.z2c(Field);

    var c_args: @Tuple(&types) = undefined;
    inline for (args, 0..) |value, i| c_args[i] = ffi.cast.z2c(value);

    const result = ffi.msg.send(receiver, ffi.cast.type.z2c(Return), ffi.Sel.get(name), c_args);
    return if (Return == bool) ffi.cast.c2z(result) else result;
}

test "helpers.call: selects conversion only for a bool return" {
    const Methods = struct {
        fn echo(_: *ffi.Object, _: *ffi.Sel, value: ffi.c.BOOL) callconv(.c) ffi.c.BOOL {
            return value;
        }
    };
    const cls = ffi.c.objc_allocateClassPair(@ptrCast(ffi.Class.lookup("NSObject").?), "ObzcHelpers2CallingBool", 0) orelse return error.ClassAllocFailed;
    defer ffi.c.objc_disposeClassPair(cls);
    const signature = if (ffi.c.BOOL == bool) "B@:B" else "c@:c";
    try std.testing.expect(ffi.c.class_addMethod(cls, @ptrCast(ffi.Sel.get("echoBool:")), @ptrCast(&Methods.echo), signature) == ffi.c.YES);
    ffi.c.objc_registerClassPair(cls);
    const object = ffi.msg.send(@as(*ffi.Class, @ptrCast(cls)), *ffi.Object, ffi.Sel.get("new"), .{});
    defer ffi.c.objc_release(@ptrCast(object));

    try std.testing.expect(!call(object, bool, "echoBool:", .{false}));
    try std.testing.expect(call(object, bool, "echoBool:", .{true}));
    try std.testing.expectEqual(ffi.c.NO, call(object, ffi.c.BOOL, "echoBool:", .{false}));
    try std.testing.expectEqual(ffi.c.YES, call(object, ffi.c.BOOL, "echoBool:", .{true}));

    const value: ffi.c.BOOL = if (ffi.c.BOOL == bool) true else 2;
    try std.testing.expect(call(object, bool, "echoBool:", .{value}));
    try std.testing.expectEqual(value, call(object, ffi.c.BOOL, "echoBool:", .{value}));
}

test "helpers.call: assembles arguments in order and converts only top-level bool" {
    const Payload = extern struct { flags: [2]bool, enabled: bool, count: i32 };
    const Callback = *const fn (i32) callconv(.c) i32;
    const Methods = struct {
        fn transform(_: *ffi.Object, _: *ffi.Sel, payload: Payload, enabled: ffi.c.BOOL, scale: f64, callback: Callback) callconv(.c) i64 {
            return @as(i64, callback(payload.count)) +
                @as(i64, @intFromFloat(scale * 10)) +
                @as(i64, @intFromBool(payload.flags[0])) +
                2 * @as(i64, @intFromBool(payload.flags[1])) +
                4 * @as(i64, @intFromBool(payload.enabled)) +
                8 * @as(i64, @intFromBool(enabled != ffi.c.NO));
        }

        fn triple(value: i32) callconv(.c) i32 {
            return value * 3;
        }
    };
    const cls = ffi.c.objc_allocateClassPair(@ptrCast(ffi.Class.lookup("NSObject").?), "ObzcHelpers2CallingAggregate", 0) orelse return error.ClassAllocFailed;
    defer ffi.c.objc_disposeClassPair(cls);
    const signature = "q@:{Payload=[2B]Bi}" ++ (if (ffi.c.BOOL == bool) "B" else "c") ++ "d^?";
    try std.testing.expect(ffi.c.class_addMethod(cls, @ptrCast(ffi.Sel.get("transform:enabled:scale:callback:")), @ptrCast(&Methods.transform), signature) == ffi.c.YES);
    ffi.c.objc_registerClassPair(cls);
    const object = ffi.msg.send(@as(*ffi.Class, @ptrCast(cls)), *ffi.Object, ffi.Sel.get("new"), .{});
    defer ffi.c.objc_release(@ptrCast(object));

    const payload: Payload = .{ .flags = .{ true, false }, .enabled = true, .count = -7 };
    const callback: Callback = &Methods.triple;
    const result = call(object, i64, "transform:enabled:scale:callback:", .{ payload, false, @as(f64, 2.5), callback });
    try std.testing.expectEqual(@as(i64, 9), result);
    const enabled = call(object, i64, "transform:enabled:scale:callback:", .{ payload, true, @as(f64, -0.5), callback });
    try std.testing.expectEqual(@as(i64, -13), enabled);
}
