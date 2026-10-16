const std = @import("std");
const objc = @import("objc");

pub const NSString = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);
    const utf8_encoding: usize = 4; // NSUTF8StringEncoding in Foundation/NSString.h.

    pub const retain = h.retain;
    pub const release = h.release;

    pub fn init(utf8: []const u8) ?*Self {
        const allocated: *Self = @ptrCast(objc.getClass("NSString").?.alloc());
        return h.msgSend(allocated, ?*Self, "initWithBytes:length:encoding:", .{ utf8.ptr, utf8.len, utf8_encoding });
    }

    /// Number of UTF-16 code units, which may differ from the UTF-8 byte count.
    pub const getLength = h.prop(usize, "length").getter;

    /// The returned slice is borrowed and remains valid only while the string is alive.
    pub fn getUTF8String(self: *Self) [:0]const u8 {
        return std.mem.span(h.msgSend(self, [*:0]const u8, "UTF8String", .{}));
    }
};

test "NSString: UTF-8 text and length" {
    const utf8: []const u8 = "café!"[0..5];
    const string = NSString.init(utf8).?;
    defer string.release();

    try std.testing.expectEqualStrings("café", string.getUTF8String());
    try std.testing.expectEqual(4, string.getLength());
}

test "NSString: embedded NUL and invalid UTF-8" {
    const string = NSString.init("A\x00B").?;
    defer string.release();
    try std.testing.expectEqual(3, string.getLength());

    const invalid = [_]u8{0xff};
    try std.testing.expect(NSString.init(&invalid) == null);
}
