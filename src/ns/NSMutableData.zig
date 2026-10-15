const std = @import("std");
const objc = @import("../root.zig");

pub const NSMutableData = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub fn new() *Self {
        return @ptrCast(objc.getClass("NSMutableData").?.new());
    }

    pub const getLength = h.prop(usize, "length").getter;
    pub const setLength = h.prop(usize, "length").setter;

    pub fn appendBytes(self: *Self, bytes: []const u8) void {
        if (bytes.len == 0) return;
        h.msgSend(self, void, "appendBytes:length:", .{ bytes.ptr, bytes.len });
    }

    /// The returned slice is invalidated by mutation or release.
    pub fn getBytes(self: *Self) []const u8 {
        const length = self.getLength();
        if (length == 0) return "";
        return h.msgSend(self, ?[*]const u8, "bytes", .{}).?[0..length];
    }

    /// The returned pointer is invalidated by mutation or release and may be null when empty.
    pub fn getMutableBytes(self: *Self) ?[*]u8 {
        return h.msgSend(self, ?[*]u8, "mutableBytes", .{});
    }
};

test "NSMutableData: resize, edit, and append bytes" {
    const data = NSMutableData.new();
    defer data.release();

    try std.testing.expectEqual(0, data.getLength());
    try std.testing.expectEqualSlices(u8, "", data.getBytes());

    data.setLength(4);
    @memcpy(data.getMutableBytes().?[0..4], "zig!");
    try std.testing.expectEqualSlices(u8, "zig!", data.getBytes());

    data.setLength(2);
    data.appendBytes("?");
    try std.testing.expectEqual(3, data.getLength());
    try std.testing.expectEqualSlices(u8, "zi?", data.getBytes());
}
