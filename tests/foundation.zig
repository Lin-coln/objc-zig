const std = @import("std");
const objc = @import("objc");

const MutableData = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const msgSend = h.msgSend;
    pub const release = h.release;
    pub const getLength = h.prop(usize, "length").getter;
    pub const setLength = h.prop(usize, "length").setter;
};

test "Foundation: allocate data, use property helpers, and copy its contents" {
    const allocated: *MutableData = @ptrCast(objc.getClass("NSMutableData").?.alloc());
    const data = allocated.msgSend(?*MutableData, "init", .{}).?;
    defer data.release();

    try std.testing.expectEqual(0, data.getLength());
    data.setLength(4);
    try std.testing.expectEqual(4, data.getLength());

    const mutable_bytes = data.msgSend(?[*]u8, "mutableBytes", .{}).?;
    @memcpy(mutable_bytes[0..4], "zig!");

    const snapshot = data.msgSend(?*objc.zig.Object, "copy", .{}).?;
    defer objc.zig.release(snapshot);

    data.setLength(2);
    try std.testing.expectEqual(2, data.getLength());
    try std.testing.expectEqual(4, objc.zig.msgSend(snapshot, usize, objc.zig.Sel.registerName("length"), .{}));
    const snapshot_bytes = objc.zig.msgSend(snapshot, [*]const u8, objc.zig.Sel.registerName("bytes"), .{});
    try std.testing.expectEqualSlices(u8, "zig!", snapshot_bytes[0..4]);
}
