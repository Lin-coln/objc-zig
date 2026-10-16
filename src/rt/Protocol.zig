const std = @import("std");
const c = @import("../c.zig").c;
const Property = @import("Property.zig").Property;

pub const Protocol = opaque {
    pub fn name(self: *Protocol) [:0]const u8 {
        return std.mem.span(c.protocol_getName(@ptrCast(self)));
    }

    pub fn conformsToProtocol(self: *Protocol, other: *Protocol) bool {
        return c.protocol_conformsToProtocol(@ptrCast(self), @ptrCast(other)) == c.YES;
    }

    pub fn isEqual(self: *Protocol, other: *Protocol) bool {
        return c.protocol_isEqual(@ptrCast(self), @ptrCast(other)) == c.YES;
    }

    pub fn property(self: *Protocol, property_name: [:0]const u8, is_required: bool, is_instance: bool) ?*Property {
        return @ptrCast(c.protocol_getProperty(
            @ptrCast(self),
            property_name,
            if (is_required) c.YES else c.NO,
            if (is_instance) c.YES else c.NO,
        ));
    }
};

test "Protocol" {
    const objc = @import("root.zig");
    try std.testing.expectEqual(null, objc.protocol("NoSuchProtocolInThisProcess"));
    try std.testing.expectEqualStrings("NSCopying", objc.protocol("NSCopying").?.name());

    const secure_coding = objc.protocol("NSSecureCoding").?;
    const coding = objc.protocol("NSCoding").?;
    try std.testing.expect(secure_coding.conformsToProtocol(coding));
    try std.testing.expect(!coding.conformsToProtocol(secure_coding));
    try std.testing.expect(coding.isEqual(objc.protocol("NSCoding").?));
    try std.testing.expect(!coding.isEqual(secure_coding));

    const nsobject = objc.protocol("NSObject").?;
    try std.testing.expectEqualStrings("hash", nsobject.property("hash", true, true).?.name());
    try std.testing.expectEqual(null, nsobject.property("hash", false, true));
}
