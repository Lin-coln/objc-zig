const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;
const mtl = @import("mtl-abi");
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLRenderPassColorAttachmentDescriptor = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const texture = h.prop("texture", ?*MTLTexture).getter;
    pub const setTexture = h.prop("texture", ?*MTLTexture).setter;
    pub const loadAction = h.prop("loadAction", mtl.MTLLoadAction).getter;
    pub const setLoadAction = h.prop("loadAction", mtl.MTLLoadAction).setter;
    pub const storeAction = h.prop("storeAction", mtl.MTLStoreAction).getter;
    pub const setStoreAction = h.prop("storeAction", mtl.MTLStoreAction).setter;
    pub const clearColor = h.prop("clearColor", mtl.MTLClearColor).getter;
    pub const setClearColor = h.prop("clearColor", mtl.MTLClearColor).setter;
};

test "MTLRenderPassColorAttachmentDescriptor: clear color struct and attachment actions" {
    const color = MTLRenderPassColorAttachmentDescriptor.new();
    defer color.release();
    try std.testing.expect(color.texture() == null);
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

test "MTLRenderPassColorAttachmentDescriptor: texture can be assigned and cleared" {
    const MTLDevice = @import("MTLDevice.zig").MTLDevice;
    const MTLTextureDescriptor = @import("MTLTextureDescriptor.zig").MTLTextureDescriptor;
    const pool = core.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const descriptor = MTLTextureDescriptor.texture2DDescriptor(mtl.MTLPixelFormatBGRA8Unorm, 8, 4, false);
    const texture = device.newTexture(descriptor).?;
    defer texture.release();
    const color = MTLRenderPassColorAttachmentDescriptor.new();
    defer color.release();

    color.setTexture(texture);
    try std.testing.expectEqual(texture, color.texture().?);
    color.setTexture(null);
    try std.testing.expect(color.texture() == null);
}
