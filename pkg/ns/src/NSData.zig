const std = @import("std");
const obzc = @import("obzc");
const Metadata = obzc.Metadata;

pub const NSData = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    /// Copies the bytes into immutable storage owned by the data object.
    pub fn init(contents: []const u8) *Self {
        return h.call(h.cls.alloc(), *Self, "initWithBytes:length:", .{ contents.ptr, contents.len });
    }

    pub const length = h.prop("length", usize).getter;

    /// The returned slice is borrowed and remains valid while the data object is alive.
    pub fn bytes(self: *Self) []const u8 {
        const byte_count = self.length();
        if (byte_count == 0) return "";
        return h.call(self, ?[*]const u8, "bytes", .{}).?[0..byte_count];
    }
};

test "NSData: new and init support empty data" {
    const created = NSData.new();
    defer created.release();
    const initialized = NSData.init("");
    defer initialized.release();

    try std.testing.expectEqual(0, created.length());
    try std.testing.expectEqualSlices(u8, "", created.bytes());
    try std.testing.expectEqual(0, initialized.length());
    try std.testing.expectEqualSlices(u8, "", initialized.bytes());
}

test "NSData: init copies bytes including embedded NUL" {
    var source = [_]u8{ 'a', 0, 'b' };
    const data = NSData.init(&source);
    defer data.release();
    source[0] = 'x';

    try std.testing.expectEqual(3, data.length());
    try std.testing.expectEqualSlices(u8, "a\x00b", data.bytes());
}
