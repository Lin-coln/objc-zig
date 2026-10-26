const std = @import("std");
const c = @import("../ffi/root.zig").c;
const rt = @import("../src/rt/root.zig");
const cast = @import("../src/utils/root.zig").cast;

/// Calls an Objective-C method using Zig-facing argument and return types.
/// Converts top-level bool values to and from BOOL; nested types and callbacks are unchanged.
pub fn call(receiver: anytype, comptime Return: type, name: [:0]const u8, args: anytype) Return {
    var method_args: Args(@TypeOf(args)) = undefined;
    inline for (args, 0..) |value, i| {
        method_args[i] = if (@TypeOf(value) == bool) cast.BOOL(value) else value;
    }

    const result = rt.msgSend(receiver, if (Return == bool) c.BOOL else Return, rt.Sel.registerName(name), method_args);
    return if (Return == bool) cast.bool(result) else result;
}

fn Args(comptime T: type) type {
    const fields = @typeInfo(T).@"struct".field_types;
    var types: [fields.len]type = undefined;
    for (fields, 0..) |Field, i| types[i] = if (Field == bool) c.BOOL else Field;
    return @Tuple(&types);
}

test "Args: converts only top-level bool parameters" {
    const Payload = extern struct { value: bool };
    const Callback = *const fn (bool) callconv(.c) bool;
    const Original = @Tuple(&.{ bool, i32, Payload, *bool, ?*rt.Object, Callback });
    const Expected = @Tuple(&.{ c.BOOL, i32, Payload, *bool, ?*rt.Object, Callback });
    try std.testing.expect(Args(Original) == Expected);
    try std.testing.expect(Args(@Tuple(&.{})) == @Tuple(&.{}));
}

test "call: normalizes nonzero BOOL returns and preserves explicit ABI types" {
    const encode = @import("../src/Block/encode.zig").encode;
    const Methods = struct {
        const value: c.BOOL = if (c.BOOL == bool) true else 2;

        fn flag(_: *rt.Object, _: *rt.Sel) callconv(.c) c.BOOL {
            return value;
        }
    };
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ObzcCallBoolTest", 0).?;
    defer rt.disposeClassPair(class);
    const selector = rt.Sel.registerName("flag");
    const encoding = comptime encode(c.BOOL) ++ "@:";
    try std.testing.expect(class.addMethod(selector, &Methods.flag, encoding));
    rt.registerClassPair(class);
    const object = rt.msgSend(class, *rt.Object, rt.Sel.registerName("new"), .{});
    defer rt.release(object);

    try std.testing.expectEqual(Methods.value, rt.msgSend(object, c.BOOL, selector, .{}));
    try std.testing.expectEqual(Methods.value, call(object, c.BOOL, "flag", .{}));
    try std.testing.expect(call(object, bool, "flag", .{}));
}
