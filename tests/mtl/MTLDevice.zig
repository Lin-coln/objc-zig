const std = @import("std");
const objc = @import("objc");
const ns = @import("objc/ns");
const macos = @import("macos");
const mtl = @import("macos/mtl-abi");
const MTLCommandQueue = @import("MTLCommandQueue.zig").MTLCommandQueue;
const MTLTextureDescriptor = @import("MTLTextureDescriptor.zig").MTLTextureDescriptor;
const MTLTexture = @import("MTLTexture.zig").MTLTexture;
const MTLCompileOptions = @import("MTLCompileOptions.zig").MTLCompileOptions;
const MTLLibrary = @import("MTLLibrary.zig").MTLLibrary;
const MTLRenderPipelineDescriptor = @import("MTLRenderPipelineDescriptor.zig").MTLRenderPipelineDescriptor;
const MTLRenderPipelineState = @import("MTLRenderPipelineState.zig").MTLRenderPipelineState;
const MTLRenderPassDescriptor = @import("MTLRenderPassDescriptor.zig").MTLRenderPassDescriptor;

pub const MTLDevice = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an owned default device, or null if Metal is unavailable.
    pub fn createSystemDefaultDevice() ?*Self {
        return @ptrCast(mtl.MTLCreateSystemDefaultDevice());
    }

    pub const newCommandQueue = h.method("newCommandQueue", fn () ?*MTLCommandQueue);
    pub const newTexture = h.method("newTextureWithDescriptor:", fn (*MTLTextureDescriptor) ?*MTLTexture);
    pub const newTextureWithIOSurface = h.method("newTextureWithDescriptor:iosurface:plane:", fn (*MTLTextureDescriptor, macos.IOSurfaceRef, usize) ?*MTLTexture);
    pub const newLibrary = h.method("newLibraryWithSource:options:error:", fn (*ns.NSString, ?*MTLCompileOptions, ?*?*ns.NSError) ?*MTLLibrary);
    pub const newRenderPipelineState = h.method("newRenderPipelineStateWithDescriptor:error:", fn (*MTLRenderPipelineDescriptor, ?*?*ns.NSError) ?*MTLRenderPipelineState);
};

test "MTLDevice: compile, render, and copy textures through a command buffer" {
    const pool = objc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
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
    var compile_error: ?*ns.NSError = null;
    const library = device.newLibrary(source, options, &compile_error) orelse {
        if (compile_error) |err| err.log();
        return error.ShaderCompilationFailed;
    };
    defer library.release();
    const vertex_name = ns.NSString.init("vertex_main").?;
    defer vertex_name.release();
    const vertex = library.newFunction(vertex_name).?;
    defer vertex.release();
    const fragment_name = ns.NSString.init("fragment_main").?;
    defer fragment_name.release();
    const fragment = library.newFunction(fragment_name).?;
    defer fragment.release();
    try std.testing.expectEqual(@as(mtl.MTLFunctionType, mtl.MTLFunctionTypeVertex), vertex.functionType());
    try std.testing.expectEqual(@as(mtl.MTLFunctionType, mtl.MTLFunctionTypeFragment), fragment.functionType());
    const missing_name = ns.NSString.init("missing_function").?;
    defer missing_name.release();
    try std.testing.expect(library.newFunction(missing_name) == null);

    const pipeline_descriptor = MTLRenderPipelineDescriptor.new();
    defer pipeline_descriptor.release();
    pipeline_descriptor.setVertexFunction(vertex);
    pipeline_descriptor.setFragmentFunction(fragment);
    pipeline_descriptor.colorAttachments().objectAtIndexedSubscript(0).setPixelFormat(mtl.MTLPixelFormatBGRA8Unorm);
    try std.testing.expectEqual(vertex, pipeline_descriptor.vertexFunction().?);
    try std.testing.expectEqual(fragment, pipeline_descriptor.fragmentFunction().?);
    var pipeline_error: ?*ns.NSError = null;
    const pipeline = device.newRenderPipelineState(pipeline_descriptor, &pipeline_error) orelse {
        if (pipeline_error) |err| err.log();
        return error.PipelineCreationFailed;
    };
    defer pipeline.release();

    const texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(mtl.MTLPixelFormatBGRA8Unorm, 4, 4, false);
    texture_descriptor.setUsage(mtl.MTLTextureUsageRenderTarget | mtl.MTLTextureUsageShaderRead);
    texture_descriptor.setStorageMode(mtl.MTLStorageModePrivate);
    const input = device.newTexture(texture_descriptor).?;
    defer input.release();
    const output = device.newTexture(texture_descriptor).?;
    defer output.release();
    const copy = device.newTexture(texture_descriptor).?;
    defer copy.release();
    try std.testing.expectEqual(4, output.width());
    try std.testing.expectEqual(4, output.height());
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatBGRA8Unorm), output.pixelFormat());
    try std.testing.expectEqual(device, output.device());

    const queue = device.newCommandQueue().?;
    defer queue.release();
    const command_buffer = queue.commandBuffer().?;
    const render_pass = MTLRenderPassDescriptor.new();
    defer render_pass.release();
    const color = render_pass.colorAttachments().objectAtIndexedSubscript(0);
    color.setTexture(output);
    color.setLoadAction(mtl.MTLLoadActionClear);
    color.setStoreAction(mtl.MTLStoreActionStore);
    color.setClearColor(.{ .red = 0, .green = 0, .blue = 0, .alpha = 1 });
    try std.testing.expectEqual(output, color.texture().?);
    const encoder = command_buffer.renderCommandEncoder(render_pass).?;
    const offset: [4]f32 = .{ 0, 0, 0, 0 };
    encoder.setRenderPipelineState(pipeline);
    encoder.setVertexBytes(&offset, @sizeOf(@TypeOf(offset)), 0);
    encoder.setFragmentTexture(input, 0);
    encoder.drawPrimitives(mtl.MTLPrimitiveTypeTriangleStrip, 0, 4);
    encoder.endEncoding();
    const blit = command_buffer.blitCommandEncoder().?;
    blit.copyFromTexture(output, copy);
    blit.endEncoding();
    command_buffer.commit();
    command_buffer.waitUntilCompleted();
    if (command_buffer.@"error"()) |err| err.log();
    try std.testing.expect(command_buffer.@"error"() == null);
    try std.testing.expectEqual(@as(mtl.MTLCommandBufferStatus, mtl.MTLCommandBufferStatusCompleted), command_buffer.status());
}

test "MTLDevice: failed shader compilation reports NSError" {
    const pool = objc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init("this is not a Metal shader").?;
    defer source.release();
    var compile_error: ?*ns.NSError = null;
    try std.testing.expect(device.newLibrary(source, null, &compile_error) == null);
    try std.testing.expect(compile_error != null);
    try std.testing.expect(compile_error.?.domain().length() != 0);
}

test "MTLDevice: create a texture backed by an IOSurface" {
    const pool = objc.AutoReleasePool.create();
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
    const descriptor = MTLTextureDescriptor.texture2DDescriptor(mtl.MTLPixelFormatBGRA8Unorm, 4, 4, false);
    descriptor.setStorageMode(mtl.MTLStorageModeShared);
    descriptor.setUsage(mtl.MTLTextureUsageShaderRead);
    const texture = device.newTextureWithIOSurface(descriptor, surface, 0).?;
    defer texture.release();
    try std.testing.expectEqual(4, texture.width());
    try std.testing.expectEqual(4, texture.height());
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatBGRA8Unorm), texture.pixelFormat());
    try std.testing.expectEqual(device, texture.device());
}
