const std = @import("std");
const objc = @import("objc");
const ns = @import("objc/ns");
const mtl = @import("objc/mtl");
const c = mtl.c;
const MTLDevice = mtl.MTLDevice;
const MTLCompileOptions = mtl.MTLCompileOptions;
const MTLRenderPipelineDescriptor = mtl.MTLRenderPipelineDescriptor;
const MTLTextureDescriptor = mtl.MTLTextureDescriptor;
const MTLRenderPassDescriptor = mtl.MTLRenderPassDescriptor;

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
    try std.testing.expectEqual(@as(c.MTLFunctionType, c.MTLFunctionTypeVertex), vertex.functionType());
    try std.testing.expectEqual(@as(c.MTLFunctionType, c.MTLFunctionTypeFragment), fragment.functionType());
    const missing_name = ns.NSString.init("missing_function").?;
    defer missing_name.release();
    try std.testing.expect(library.newFunction(missing_name) == null);

    const pipeline_descriptor = MTLRenderPipelineDescriptor.new();
    defer pipeline_descriptor.release();
    pipeline_descriptor.setVertexFunction(vertex);
    pipeline_descriptor.setFragmentFunction(fragment);
    pipeline_descriptor.colorAttachments().objectAtIndexedSubscript(0).setPixelFormat(c.MTLPixelFormatBGRA8Unorm);
    try std.testing.expectEqual(vertex, pipeline_descriptor.vertexFunction().?);
    try std.testing.expectEqual(fragment, pipeline_descriptor.fragmentFunction().?);
    var pipeline_error: ?*ns.NSError = null;
    const pipeline = device.newRenderPipelineState(pipeline_descriptor, &pipeline_error) orelse {
        if (pipeline_error) |err| err.log();
        return error.PipelineCreationFailed;
    };
    defer pipeline.release();

    const texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(c.MTLPixelFormatBGRA8Unorm, 4, 4, false);
    texture_descriptor.setUsage(c.MTLTextureUsageRenderTarget | c.MTLTextureUsageShaderRead);
    texture_descriptor.setStorageMode(c.MTLStorageModePrivate);
    const input = device.newTexture(texture_descriptor).?;
    defer input.release();
    const output = device.newTexture(texture_descriptor).?;
    defer output.release();
    const copy = device.newTexture(texture_descriptor).?;
    defer copy.release();
    try std.testing.expectEqual(4, output.width());
    try std.testing.expectEqual(4, output.height());
    try std.testing.expectEqual(@as(c.MTLPixelFormat, c.MTLPixelFormatBGRA8Unorm), output.pixelFormat());
    try std.testing.expectEqual(device, output.device());

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
    try std.testing.expectEqual(output, color.texture().?);
    const encoder = command_buffer.renderCommandEncoder(render_pass).?;
    const offset: [4]f32 = .{ 0, 0, 0, 0 };
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
}
