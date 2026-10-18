const std = @import("std");
const objc = @import("objc");
const mtl = @import("mtl-abi");

pub const MTLTextureDescriptor = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    /// Returns an autoreleased descriptor; retain it to keep it beyond the current pool.
    pub fn texture2DDescriptor(pixel_format: mtl.MTLPixelFormat, width_value: usize, height_value: usize, mipmapped: bool) *Self {
        const create = h.cls.method("texture2DDescriptorWithPixelFormat:width:height:mipmapped:", fn (mtl.MTLPixelFormat, usize, usize, objc.c.BOOL) *Self);
        return create(pixel_format, width_value, height_value, objc.utils.cast.BOOL(mipmapped));
    }

    pub const pixelFormat = h.prop(mtl.MTLPixelFormat, "pixelFormat").getter;
    pub const setPixelFormat = h.prop(mtl.MTLPixelFormat, "pixelFormat").setter;
    pub const width = h.prop(usize, "width").getter;
    pub const setWidth = h.prop(usize, "width").setter;
    pub const height = h.prop(usize, "height").getter;
    pub const setHeight = h.prop(usize, "height").setter;
    pub const mipmapLevelCount = h.prop(usize, "mipmapLevelCount").getter;
    pub const usage = h.prop(mtl.MTLTextureUsage, "usage").getter;
    pub const setUsage = h.prop(mtl.MTLTextureUsage, "usage").setter;
    pub const storageMode = h.prop(mtl.MTLStorageMode, "storageMode").getter;
    pub const setStorageMode = h.prop(mtl.MTLStorageMode, "storageMode").setter;
};

test "MTLTextureDescriptor: configure texture dimensions and storage" {
    const pool = objc.AutoReleasePool.create();
    defer pool.release();
    const descriptor = MTLTextureDescriptor.texture2DDescriptor(mtl.MTLPixelFormatBGRA8Unorm, 32, 16, false);
    descriptor.setUsage(mtl.MTLTextureUsageShaderRead | mtl.MTLTextureUsageRenderTarget);
    descriptor.setStorageMode(mtl.MTLStorageModePrivate);

    try std.testing.expectEqual(32, descriptor.width());
    try std.testing.expectEqual(16, descriptor.height());
    try std.testing.expectEqual(1, descriptor.mipmapLevelCount());
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatBGRA8Unorm), descriptor.pixelFormat());
    try std.testing.expectEqual(@as(mtl.MTLTextureUsage, mtl.MTLTextureUsageShaderRead | mtl.MTLTextureUsageRenderTarget), descriptor.usage());
    try std.testing.expectEqual(@as(mtl.MTLStorageMode, mtl.MTLStorageModePrivate), descriptor.storageMode());

    descriptor.setWidth(64);
    descriptor.setHeight(48);
    descriptor.setPixelFormat(mtl.MTLPixelFormatRGBA16Float);
    try std.testing.expectEqual(64, descriptor.width());
    try std.testing.expectEqual(48, descriptor.height());
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatRGBA16Float), descriptor.pixelFormat());

    const mipmapped = MTLTextureDescriptor.texture2DDescriptor(mtl.MTLPixelFormatBGRA8Unorm, 32, 16, true);
    try std.testing.expectEqual(6, mipmapped.mipmapLevelCount());
}
