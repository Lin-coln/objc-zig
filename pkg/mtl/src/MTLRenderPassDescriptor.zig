const std = @import("std");
const objc = @import("objc");
const mtl = @import("mtl-abi");
const MTLRenderPassColorAttachmentDescriptorArray = @import("MTLRenderPassColorAttachmentDescriptorArray.zig").MTLRenderPassColorAttachmentDescriptorArray;

pub const MTLRenderPassDescriptor = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    /// Borrowed attachment array, owned by this descriptor.
    pub const colorAttachments = h.prop(*MTLRenderPassColorAttachmentDescriptorArray, "colorAttachments").getter;
};

test "MTLRenderPassDescriptor: clear color struct and attachment actions" {
    const descriptor = MTLRenderPassDescriptor.new();
    defer descriptor.release();
    const color = descriptor.colorAttachments().objectAtIndexedSubscript(0);
    try std.testing.expect(color.texture() == null);
    color.setTexture(null);
    color.setLoadAction(mtl.MTLLoadActionClear);
    color.setStoreAction(mtl.MTLStoreActionStore);
    color.setClearColor(.{ .red = 0.25, .green = 0.5, .blue = 0.75, .alpha = 1 });

    try std.testing.expectEqual(@as(mtl.MTLLoadAction, mtl.MTLLoadActionClear), color.loadAction());
    try std.testing.expectEqual(@as(mtl.MTLStoreAction, mtl.MTLStoreActionStore), color.storeAction());
    const clear = color.clearColor();
    try std.testing.expectEqual(0.25, clear.red);
    try std.testing.expectEqual(0.5, clear.green);
    try std.testing.expectEqual(0.75, clear.blue);
    try std.testing.expectEqual(1, clear.alpha);
}
