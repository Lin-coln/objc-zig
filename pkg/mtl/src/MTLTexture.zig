const std = @import("std");
const obzc = @import("obzc");
const mtl = @import("mtl-abi");
const MTLDevice = @import("MTLDevice.zig").MTLDevice;

pub const MTLTexture = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const width = h.m.of("width", fn () usize);
    pub const height = h.m.of("height", fn () usize);
    pub const pixelFormat = h.m.of("pixelFormat", fn () mtl.MTLPixelFormat);
    /// Borrowed device that created this texture.
    pub const device = h.m.of("device", fn () *MTLDevice);
};

test "MTLTexture: dimensions, format, and device describe the created resource" {
    const MTLTextureDescriptor = @import("MTLTextureDescriptor.zig").MTLTextureDescriptor;
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const descriptor = MTLTextureDescriptor.texture2DDescriptor(mtl.MTLPixelFormatBGRA8Unorm, 8, 4, false);
    const texture = device.newTexture(descriptor).?;
    defer texture.release();

    try std.testing.expectEqual(8, texture.width());
    try std.testing.expectEqual(4, texture.height());
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatBGRA8Unorm), texture.pixelFormat());
    try std.testing.expectEqual(device, texture.device());
}
