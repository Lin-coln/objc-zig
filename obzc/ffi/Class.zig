const std = @import("std");
const c = @import("c.zig").c;

pub const Class = opaque {
    const Self = @This();

    /// Looks up an already registered class. Does not allocate or initialize an object.
    pub fn lookup(name: [:0]const u8) ?*Self {
        return @ptrCast(c.objc_getClass(name));
    }
};

test "Class.lookup: forwards the class name and preserves a missing result" {
    const object = Class.lookup("NSObject").?;
    const number = Class.lookup("NSNumber").?;
    try std.testing.expectEqualStrings("NSObject", std.mem.span(c.class_getName(@ptrCast(object))));
    try std.testing.expectEqualStrings("NSNumber", std.mem.span(c.class_getName(@ptrCast(number))));
    try std.testing.expectEqual(null, Class.lookup("ObzcFfiMissingClass"));
}
