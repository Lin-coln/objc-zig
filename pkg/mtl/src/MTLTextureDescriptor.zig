const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;
const mtl = @import("mtl-abi");

pub const MTLTextureDescriptor = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    /// Returns an autoreleased descriptor; retain it to keep it beyond the current pool.
    pub fn texture2DDescriptor(pixel_format: mtl.MTLPixelFormat, width_value: usize, height_value: usize, mipmapped: bool) *Self {
        return h.cls.call(*Self, "texture2DDescriptorWithPixelFormat:width:height:mipmapped:", .{
            pixel_format,
            width_value,
            height_value,
            mipmapped,
        });
    }

    pub const pixelFormat = h.prop("pixelFormat", mtl.MTLPixelFormat).getter;
    pub const setPixelFormat = h.prop("pixelFormat", mtl.MTLPixelFormat).setter;
    pub const width = h.prop("width", usize).getter;
    pub const setWidth = h.prop("width", usize).setter;
    pub const height = h.prop("height", usize).getter;
    pub const setHeight = h.prop("height", usize).setter;
    pub const mipmapLevelCount = h.prop("mipmapLevelCount", usize).getter;
    pub const usage = h.prop("usage", mtl.MTLTextureUsage).getter;
    pub const setUsage = h.prop("usage", mtl.MTLTextureUsage).setter;
    pub const storageMode = h.prop("storageMode", mtl.MTLStorageMode).getter;
    pub const setStorageMode = h.prop("storageMode", mtl.MTLStorageMode).setter;
};

test "MTLTextureDescriptor: configure texture dimensions and storage" {
    const pool = core.AutoReleasePool.create();
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
