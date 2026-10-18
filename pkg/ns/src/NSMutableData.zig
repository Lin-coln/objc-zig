const std = @import("std");
const obzc = @import("obzc");

pub const NSMutableData = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const new = h.cls.new;
    pub const retain = h.retain;
    pub const release = h.release;

    pub const length = h.prop(usize, "length").getter;
    pub const setLength = h.prop(usize, "length").setter;

    pub fn appendBytes(self: *Self, appended_bytes: []const u8) void {
        if (appended_bytes.len == 0) return;
        h.msgSend(self, void, "appendBytes:length:", .{ appended_bytes.ptr, appended_bytes.len });
    }

    /// The returned slice is invalidated by mutation or release.
    pub fn bytes(self: *Self) []const u8 {
        const byte_count = self.length();
        if (byte_count == 0) return "";
        return h.msgSend(self, ?[*]const u8, "bytes", .{}).?[0..byte_count];
    }

    /// The returned pointer is invalidated by mutation or release and may be null when empty.
    pub const mutableBytes = h.method("mutableBytes", fn () ?[*]u8);
};

test "NSMutableData: resize, edit, and append bytes" {
    const data = NSMutableData.new();
    defer data.release();

    try std.testing.expectEqual(0, data.length());
    try std.testing.expectEqualSlices(u8, "", data.bytes());

    data.setLength(4);
    @memcpy(data.mutableBytes().?[0..4], "zig!");
    try std.testing.expectEqualSlices(u8, "zig!", data.bytes());

    data.setLength(2);
    data.appendBytes("?");
    try std.testing.expectEqual(3, data.length());
    try std.testing.expectEqualSlices(u8, "zi?", data.bytes());
}
