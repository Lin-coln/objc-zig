const std = @import("std");
const objc = @import("root.zig");

/// The registered class with this name, or null if no such class is registered.
pub fn getClass(name: [:0]const u8) ?*Class {
    return @ptrCast(objc.rt.getClass(name));
}

/// An Objective-C class object. Obtain one with `getClass`.
pub const Class = opaque {
    const Self = @This();

    /// Sends the selector named `sel` to the class itself (a class method).
    pub fn msgSend(self: *Self, comptime Return: type, sel: [:0]const u8, args: anytype) Return {
        return objc.rt.msgSend(@as(*objc.rt.Class, @ptrCast(self)), Return, objc.rt.Sel.registerName(sel), args);
    }

    /// Sends `alloc` to the class, returning an uninitialized instance to be sent an `init...` message.
    pub fn alloc(self: *Self) *objc.rt.Object {
        return self.msgSend(?*objc.rt.Object, "alloc", .{}).?;
    }

    /// Sends `new` to the class, returning a newly allocated and initialized instance.
    pub fn new(self: *Self) *objc.rt.Object {
        return self.msgSend(?*objc.rt.Object, "new", .{}).?;
    }
};

test "Class" {
    const object = getClass("NSObject").?.new();
    defer objc.rt.release(object);
    try std.testing.expectEqual(null, getClass("NoSuchClassName"));
}
