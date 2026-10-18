const std = @import("std");
const obzc = @import("obzc");
const macos = @import("macos/abi");
const mtl = @import("obzc-mtl");
const c = mtl.c;
const MTLDevice = mtl.MTLDevice;
const MTLTextureDescriptor = mtl.MTLTextureDescriptor;

test "MTLDevice: create a texture backed by an IOSurface" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const surface_properties = macos.CFDictionaryCreateMutable(null, 0, &macos.kCFTypeDictionaryKeyCallBacks, &macos.kCFTypeDictionaryValueCallBacks).?;
    defer macos.CFRelease(surface_properties);
    const attributes = macos.CFDictionaryCreateMutable(null, 0, &macos.kCFTypeDictionaryKeyCallBacks, &macos.kCFTypeDictionaryValueCallBacks).?;
    defer macos.CFRelease(attributes);
    macos.CFDictionarySetValue(attributes, macos.kCVPixelBufferIOSurfacePropertiesKey, surface_properties);
    macos.CFDictionarySetValue(attributes, macos.kCVPixelBufferMetalCompatibilityKey, macos.kCFBooleanTrue);
    var pixel_buffer: macos.CVPixelBufferRef = null;
    const status = macos.CVPixelBufferCreate(null, 4, 4, macos.kCVPixelFormatType_32BGRA, attributes, &pixel_buffer);
    if (status == macos.kCVReturnAllocationFailed) {
        std.debug.print("Metal IOSurface test skipped: this environment cannot allocate an IOSurface-backed pixel buffer.\n", .{});
        return error.SkipZigTest;
    }
    try std.testing.expectEqual(macos.kCVReturnSuccess, status);
    defer macos.CVBufferRelease(pixel_buffer);
    const surface = macos.CVPixelBufferGetIOSurface(pixel_buffer).?;
    const descriptor = MTLTextureDescriptor.texture2DDescriptor(c.MTLPixelFormatBGRA8Unorm, 4, 4, false);
    descriptor.setStorageMode(c.MTLStorageModeShared);
    descriptor.setUsage(c.MTLTextureUsageShaderRead);
    const texture = device.newTextureWithIOSurface(descriptor, surface, 0).?;
    defer texture.release();
    try std.testing.expectEqual(4, texture.width());
    try std.testing.expectEqual(4, texture.height());
    try std.testing.expectEqual(@as(c.MTLPixelFormat, c.MTLPixelFormatBGRA8Unorm), texture.pixelFormat());
    try std.testing.expectEqual(device, texture.device());
}
