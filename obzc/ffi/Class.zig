const std = @import("std");
const c = @import("c.zig").c;
const Property = @import("Property.zig").Property;

pub const Class = opaque {
    const Self = @This();

    /// Looks up an already registered class. Does not allocate or initialize an object.
    pub fn lookup(name: [:0]const u8) ?*Self {
        return @ptrCast(c.objc_getClass(name));
    }

    pub fn getProperty(self: *Self, name: [:0]const u8) ?*Property {
        return @ptrCast(c.class_getProperty(@ptrCast(self), name));
    }
};

test "Class.lookup: forwards the class name and preserves a missing result" {
    const object = Class.lookup("NSObject").?;
    const number = Class.lookup("NSNumber").?;
    try std.testing.expectEqualStrings("NSObject", std.mem.span(c.class_getName(@ptrCast(object))));
    try std.testing.expectEqualStrings("NSNumber", std.mem.span(c.class_getName(@ptrCast(number))));
    try std.testing.expectEqual(null, Class.lookup("ObzcFfiMissingClass"));
}

test "Class.getProperty: forwards the class and property name and preserves missing results" {
    const string = Class.lookup("NSString").?;
    const operation = Class.lookup("NSOperation").?;
    const length = string.getProperty("length").?;
    const cancelled = operation.getProperty("cancelled").?;
    try std.testing.expectEqualStrings("length", std.mem.span(c.property_getName(@ptrCast(length))));
    try std.testing.expectEqualStrings("cancelled", std.mem.span(c.property_getName(@ptrCast(cancelled))));
    try std.testing.expectEqual(null, string.getProperty("cancelled"));
    try std.testing.expectEqual(null, operation.getProperty("ObzcFfiMissingProperty"));
}
