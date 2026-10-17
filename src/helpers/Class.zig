const std = @import("std");
const objc = @import("../root.zig");

/// Class helpers for a wrapper whose type or type factory is named after its Objective-C class.
pub fn Class(comptime T: type) type {
    const class_name = comptime objc.utils.resolveTypeName(@typeName(T));

    return struct {
        /// Sends `alloc` to the class, returning an uninitialized instance to be sent an `init...` message.
        pub fn alloc() *T {
            return msgSend(?*T, "alloc", .{}).?;
        }

        /// Sends `new` to the class, returning a newly allocated and initialized instance.
        pub fn new() *T {
            return msgSend(?*T, "new", .{}).?;
        }

        /// Sends the selector named `sel` to the class itself (a class method).
        pub fn msgSend(comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            return objc.rt.msgSend(getClass(), Return, objc.rt.Sel.registerName(sel), args);
        }

        /// Returns the Objective-C class bound to the wrapper type.
        pub fn getClass() *objc.rt.Class {
            return objc.rt.getClass(class_name).?;
        }
    };
}

test "helpers.Class: class messages, new and alloc" {
    const NSMutableData = opaque {};
    const h = Class(NSMutableData);
    const rt = objc.rt;
    const length = rt.Sel.registerName("length");
    const set_length = rt.Sel.registerName("setLength:");

    try std.testing.expectEqual(rt.getClass("NSMutableData").?, h.msgSend(*rt.Class, "class", .{}));

    const created = h.new();
    defer rt.release(@ptrCast(created));
    rt.msgSend(created, void, set_length, .{@as(usize, 5)});
    try std.testing.expectEqual(5, rt.msgSend(created, usize, length, .{}));

    const allocated = h.alloc();
    const initialized = rt.msgSend(allocated, ?*NSMutableData, rt.Sel.registerName("init"), .{}).?;
    defer rt.release(@ptrCast(initialized));
    rt.msgSend(initialized, void, set_length, .{@as(usize, 9)});
    try std.testing.expectEqual(9, rt.msgSend(initialized, usize, length, .{}));
}
