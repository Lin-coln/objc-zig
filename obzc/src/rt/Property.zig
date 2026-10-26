const std = @import("std");
const objc = @import("objc/root.zig");
const c = @import("../../ffi/root.zig").c;

pub const Property = opaque {
    pub fn getName(self: *Property) [:0]const u8 {
        return std.mem.span(c.property_getName(@ptrCast(self)));
    }

    /// The returned string is allocated with `malloc` and must be freed with `std.c.free`.
    pub fn copyAttributeValue(self: *Property, attribute: [:0]const u8) ?[:0]u8 {
        return std.mem.span(c.property_copyAttributeValue(@ptrCast(self), attribute) orelse return null);
    }
};

test "Property" {
    const length = objc.getClass("NSString").?.getProperty("length").?;
    try std.testing.expectEqualStrings("length", length.getName());

    const @"type" = length.copyAttributeValue("T").?;
    defer std.c.free(@"type".ptr);
    try std.testing.expectEqualStrings("Q", @"type");

    const readonly = length.copyAttributeValue("R").?;
    defer std.c.free(readonly.ptr);
    try std.testing.expectEqualStrings("", readonly);

    try std.testing.expectEqual(null, length.copyAttributeValue("W"));
}
