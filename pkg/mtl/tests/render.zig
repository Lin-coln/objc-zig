const std = @import("std");
const core = @import("core");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const mtl = @import("obzc-mtl");
const c = mtl.c;
const MTLDevice = mtl.MTLDevice;
const MTLCompileOptions = mtl.MTLCompileOptions;
const MTLRenderPipelineDescriptor = mtl.MTLRenderPipelineDescriptor;
const MTLTextureDescriptor = mtl.MTLTextureDescriptor;
const MTLRenderPassDescriptor = mtl.MTLRenderPassDescriptor;

test "Metal: compile, render, and read copied pixels through an IOSurface" {
    const pool = core.AutoReleasePool.create();
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
    try std.testing.expectEqual(macos.kCVReturnSuccess, status);
    defer macos.CVBufferRelease(pixel_buffer);
    const surface = macos.CVPixelBufferGetIOSurface(pixel_buffer).?;
    {
        try std.testing.expectEqual(macos.kCVReturnSuccess, macos.CVPixelBufferLockBaseAddress(pixel_buffer, 0));
        defer _ = macos.CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
        const pixels: [*]u8 = @ptrCast(macos.CVPixelBufferGetBaseAddress(pixel_buffer).?);
        @memset(pixels[0 .. macos.CVPixelBufferGetBytesPerRow(pixel_buffer) * 4], 0);
    }

    const source = ns.NSString.init(
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\vertex float4 vertex_main(uint id [[vertex_id]], constant float4 &offset [[buffer(0)]]) {
        \\    const float2 positions[4] = {float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1)};
        \\    return float4(positions[id], 0, 1) + offset;
        \\}
        \\fragment float4 fragment_main(texture2d<float> input [[texture(0)]]) {
        \\    return float4(float(input.get_width()) / 4.0, 0, 0, 1);
        \\}
    ).?;
    defer source.release();
    const options = MTLCompileOptions.new();
    defer options.release();
    const library = try device.newLibrary(source, options);
    defer library.release();
    const vertex_name = ns.NSString.init("vertex_main").?;
    defer vertex_name.release();
    const vertex = library.newFunction(vertex_name).?;
    defer vertex.release();
    const fragment_name = ns.NSString.init("fragment_main").?;
    defer fragment_name.release();
    const fragment = library.newFunction(fragment_name).?;
    defer fragment.release();
    const pipeline_descriptor = MTLRenderPipelineDescriptor.new();
    defer pipeline_descriptor.release();
    pipeline_descriptor.setVertexFunction(vertex);
    pipeline_descriptor.setFragmentFunction(fragment);
    pipeline_descriptor.colorAttachments().objectAtIndexedSubscript(0).setPixelFormat(c.MTLPixelFormatBGRA8Unorm);
    const pipeline = try device.newRenderPipelineState(pipeline_descriptor);
    defer pipeline.release();

    const texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(c.MTLPixelFormatBGRA8Unorm, 4, 4, false);
    texture_descriptor.setUsage(c.MTLTextureUsageRenderTarget | c.MTLTextureUsageShaderRead);
    texture_descriptor.setStorageMode(c.MTLStorageModePrivate);
    const input = device.newTexture(texture_descriptor).?;
    defer input.release();
    const output = device.newTexture(texture_descriptor).?;
    defer output.release();
    const copy_descriptor = MTLTextureDescriptor.texture2DDescriptor(c.MTLPixelFormatBGRA8Unorm, 4, 4, false);
    copy_descriptor.setStorageMode(c.MTLStorageModeShared);
    const copy = device.newTextureWithIOSurface(copy_descriptor, surface, 0).?;
    defer copy.release();

    const queue = device.newCommandQueue().?;
    defer queue.release();
    const command_buffer = queue.commandBuffer().?;
    const render_pass = MTLRenderPassDescriptor.new();
    defer render_pass.release();
    const color = render_pass.colorAttachments().objectAtIndexedSubscript(0);
    color.setTexture(output);
    color.setLoadAction(c.MTLLoadActionClear);
    color.setStoreAction(c.MTLStoreActionStore);
    color.setClearColor(.{ .red = 0, .green = 0, .blue = 0, .alpha = 1 });
    const encoder = command_buffer.renderCommandEncoder(render_pass).?;
    // Shift the quad by one pixel so the readback checks vertex bytes and the render-pass clear as well.
    const offset: [4]f32 = .{ 0.5, 0, 0, 0 };
    encoder.setRenderPipelineState(pipeline);
    encoder.setVertexBytes(&offset, @sizeOf(@TypeOf(offset)), 0);
    encoder.setFragmentTexture(input, 0);
    encoder.drawPrimitives(c.MTLPrimitiveTypeTriangleStrip, 0, 4);
    encoder.endEncoding();
    const blit = command_buffer.blitCommandEncoder().?;
    blit.copyFromTexture(output, copy);
    blit.endEncoding();
    command_buffer.commit();
    command_buffer.waitUntilCompleted();
    if (command_buffer.@"error"()) |err| err.log();
    try std.testing.expect(command_buffer.@"error"() == null);
    try std.testing.expectEqual(@as(c.MTLCommandBufferStatus, c.MTLCommandBufferStatusCompleted), command_buffer.status());

    // Check every pixel after the GPU finishes; successful submission alone does not prove that rendering or copying worked.
    try std.testing.expectEqual(macos.kCVReturnSuccess, macos.CVPixelBufferLockBaseAddress(pixel_buffer, macos.kCVPixelBufferLock_ReadOnly));
    defer _ = macos.CVPixelBufferUnlockBaseAddress(pixel_buffer, macos.kCVPixelBufferLock_ReadOnly);
    const pixels: [*]const u8 = @ptrCast(macos.CVPixelBufferGetBaseAddress(pixel_buffer).?);
    const bytes_per_row = macos.CVPixelBufferGetBytesPerRow(pixel_buffer);
    for (0..4) |y| {
        for (0..4) |x| {
            const pixel_offset = y * bytes_per_row + x * 4;
            const expected: [4]u8 = if (x == 0) .{ 0, 0, 0, 255 } else .{ 0, 0, 255, 255 };
            try std.testing.expectEqualSlices(u8, &expected, pixels[pixel_offset..][0..4]);
        }
    }
}
