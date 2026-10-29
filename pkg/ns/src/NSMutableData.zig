const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;

pub const NSMutableData = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const new = h.cls.new;
    pub const retain = h.retain;
    pub const release = h.release;

    pub const length = h.prop("length", usize).getter;
    pub const setLength = h.prop("length", usize).setter;

    pub fn appendBytes(self: *Self, appended_bytes: []const u8) void {
        if (appended_bytes.len == 0) return;
        h.call(self, void, "appendBytes:length:", .{ appended_bytes.ptr, appended_bytes.len });
    }

    /// The returned slice is invalidated by mutation or release.
    pub fn bytes(self: *Self) []const u8 {
        const byte_count = self.length();
        if (byte_count == 0) return "";
        return h.call(self, ?[*]const u8, "bytes", .{}).?[0..byte_count];
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
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, data.bytes());
    @memcpy(data.mutableBytes().?[0..4], "zig!");
    try std.testing.expectEqualSlices(u8, "zig!", data.bytes());

    data.setLength(2);
    data.appendBytes("?");
    try std.testing.expectEqual(3, data.length());
    try std.testing.expectEqualSlices(u8, "zi?", data.bytes());

    data.appendBytes("");
    try std.testing.expectEqualSlices(u8, "zi?", data.bytes());
    data.setLength(0);
    try std.testing.expectEqual(0, data.length());
    try std.testing.expectEqualSlices(u8, "", data.bytes());
}
