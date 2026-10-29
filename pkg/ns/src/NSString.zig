const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;

pub const NSString = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);
    const utf8_encoding: usize = 4; // NSUTF8StringEncoding in Foundation/NSString.h.

    pub const retain = h.retain;
    pub const release = h.release;

    pub fn init(utf8: []const u8) ?*Self {
        const allocated: *Self = h.cls.alloc();
        return h.call(allocated, ?*Self, "initWithBytes:length:encoding:", .{ utf8.ptr, utf8.len, utf8_encoding });
    }

    /// Number of UTF-16 code units, which may differ from the UTF-8 byte count.
    pub const length = h.prop("length", usize).getter;

    /// Borrows UTF-8 bytes, including embedded NULs. Copy before leaving the current
    /// autorelease pool or releasing the string; the buffer may have a shorter lifetime.
    pub fn utf8String(self: *Self) []const u8 {
        if (self.length() == 0) return "";
        const byte_count = h.call(self, usize, "lengthOfBytesUsingEncoding:", .{utf8_encoding});
        return h.call(self, ?[*]const u8, "UTF8String", .{}).?[0..byte_count];
    }
};

test "NSString: UTF-8 text and length" {
    const utf8: []const u8 = "café!"[0..5];
    const string = NSString.init(utf8).?;
    defer string.release();

    try std.testing.expectEqualStrings("café", string.utf8String());
    try std.testing.expectEqual(4, string.length());
}

test "NSString: embedded NUL and invalid UTF-8" {
    const string = NSString.init("A\x00B").?;
    defer string.release();
    try std.testing.expectEqual(3, string.length());
    try std.testing.expectEqualStrings("A\x00B", string.utf8String());

    const invalid = [_]u8{0xff};
    try std.testing.expect(NSString.init(&invalid) == null);
}

test "NSString: empty strings and UTF-16 surrogate pairs" {
    const empty = NSString.init("").?;
    defer empty.release();
    try std.testing.expectEqual(0, empty.length());
    try std.testing.expectEqualStrings("", empty.utf8String());

    const emoji = NSString.init("\u{1f600}").?;
    defer emoji.release();
    try std.testing.expectEqual(2, emoji.length());
    try std.testing.expectEqualStrings("\u{1f600}", emoji.utf8String());
}

test "NSString: init copies the caller's UTF-8 bytes" {
    var source = [_]u8{ 'c', 'o', 'p', 'y' };
    const string = NSString.init(&source).?;
    defer string.release();
    @memset(&source, 'x');

    try std.testing.expectEqualStrings("copy", string.utf8String());
}
