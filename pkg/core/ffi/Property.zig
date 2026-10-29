const std = @import("std");
const c = @import("c.zig").c;

pub const Property = opaque {
    const Self = @This();

    pub fn name(self: *Self) [:0]const u8 {
        const val = c.property_getName(@ptrCast(self));
        return std.mem.span(val);
    }

    /// The returned string is allocated with `malloc` and must be freed with `std.c.free`.
    pub fn copyAttributeValue(self: *Self, attribute: [:0]const u8) ?[:0]u8 {
        const val = c.property_copyAttributeValue(@ptrCast(self), attribute) orelse return null;
        return std.mem.span(val);
    }
};

test "Property.name: returns the name of the supplied metadata as a sentinel slice" {
    const properties = .{
        .{ "NSString", "length" },
        .{ "NSOperation", "cancelled" },
    };
    inline for (properties) |entry| {
        const cls = c.objc_getClass(entry[0]).?;
        const property: *Property = @ptrCast(c.class_getProperty(cls, entry[1]).?);
        const name = property.name();
        try std.testing.expectEqualStrings(entry[1], name);
        try std.testing.expectEqual(@as(u8, 0), name.ptr[name.len]);
    }
}

test "Property.copyAttributeValue: distinguishes nonempty, empty and missing attributes" {
    const cls = c.objc_getClass("NSString").?;
    const property: *Property = @ptrCast(c.class_getProperty(cls, "length").?);

    const encoding = property.copyAttributeValue("T").?;
    defer std.c.free(encoding.ptr);
    try std.testing.expectEqualStrings("Q", encoding);
    try std.testing.expectEqual(@as(u8, 0), encoding.ptr[encoding.len]);

    const readonly = property.copyAttributeValue("R").?;
    defer std.c.free(readonly.ptr);
    try std.testing.expectEqualStrings("", readonly);
    try std.testing.expectEqual(@as(u8, 0), readonly.ptr[0]);

    try std.testing.expectEqual(null, property.copyAttributeValue("W"));
}
