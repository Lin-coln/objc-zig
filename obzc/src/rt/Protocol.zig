const std = @import("std");
const c = @import("../c.zig").c;
const Property = @import("Property.zig").Property;

pub const Protocol = opaque {
    pub fn getName(self: *Protocol) [:0]const u8 {
        return std.mem.span(c.protocol_getName(@ptrCast(self)));
    }

    pub fn conformsToProtocol(self: *Protocol, other: *Protocol) bool {
        return c.protocol_conformsToProtocol(@ptrCast(self), @ptrCast(other)) == c.YES;
    }

    pub fn isEqual(self: *Protocol, other: *Protocol) bool {
        return c.protocol_isEqual(@ptrCast(self), @ptrCast(other)) == c.YES;
    }

    pub fn getProperty(self: *Protocol, property_name: [:0]const u8, is_required: bool, is_instance: bool) ?*Property {
        return @ptrCast(c.protocol_getProperty(
            @ptrCast(self),
            property_name,
            if (is_required) c.YES else c.NO,
            if (is_instance) c.YES else c.NO,
        ));
    }
};

test "Protocol" {
    const rt = @import("root.zig");
    try std.testing.expectEqual(null, rt.getProtocol("NoSuchProtocolInThisProcess"));
    try std.testing.expectEqualStrings("NSCopying", rt.getProtocol("NSCopying").?.getName());

    const secure_coding = rt.getProtocol("NSSecureCoding").?;
    const coding = rt.getProtocol("NSCoding").?;
    try std.testing.expect(secure_coding.conformsToProtocol(coding));
    try std.testing.expect(!coding.conformsToProtocol(secure_coding));
    try std.testing.expect(coding.isEqual(rt.getProtocol("NSCoding").?));
    try std.testing.expect(!coding.isEqual(secure_coding));

    const nsobject = rt.getProtocol("NSObject").?;
    try std.testing.expectEqualStrings("hash", nsobject.getProperty("hash", true, true).?.getName());
    try std.testing.expectEqual(null, nsobject.getProperty("hash", false, true));
}
