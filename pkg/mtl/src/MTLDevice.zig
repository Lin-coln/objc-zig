const std = @import("std");
const builtin = @import("builtin");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const mtl = @import("mtl-abi");
const MTLCommandQueue = @import("MTLCommandQueue.zig").MTLCommandQueue;
const MTLTextureDescriptor = @import("MTLTextureDescriptor.zig").MTLTextureDescriptor;
const MTLTexture = @import("MTLTexture.zig").MTLTexture;
const MTLCompileOptions = @import("MTLCompileOptions.zig").MTLCompileOptions;
const MTLLibrary = @import("MTLLibrary.zig").MTLLibrary;
const MTLRenderPipelineDescriptor = @import("MTLRenderPipelineDescriptor.zig").MTLRenderPipelineDescriptor;
const MTLRenderPipelineState = @import("MTLRenderPipelineState.zig").MTLRenderPipelineState;

pub const MTLDevice = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an owned default device, or null if Metal is unavailable.
    pub fn createSystemDefaultDevice() ?*Self {
        return @ptrCast(mtl.MTLCreateSystemDefaultDevice());
    }

    pub const newCommandQueue = h.method("newCommandQueue", fn () ?*MTLCommandQueue);
    pub const newTexture = h.method("newTextureWithDescriptor:", fn (*MTLTextureDescriptor) ?*MTLTexture);
    pub const newTextureWithIOSurface = h.method("newTextureWithDescriptor:iosurface:plane:", fn (*MTLTextureDescriptor, macos.IOSurfaceRef, usize) ?*MTLTexture);

    /// Returns an owned library. Logs the SDK error when compilation fails.
    pub fn newLibrary(self: *Self, source: *ns.NSString, options: ?*MTLCompileOptions) !*MTLLibrary {
        var err: ?*ns.NSError = null;
        const library = h.call(self, ?*MTLLibrary, "newLibraryWithSource:options:error:", .{ source, options, &err });
        if (library) |value| return value;

        if (err) |ns_error| ns_error.log() else if (!builtin.is_test)
            std.log.err("MTLDevice.newLibrary failed without NSError", .{});
        return error.NewLibraryFailed;
    }

    /// Returns an owned pipeline state. Logs the SDK error when creation fails.
    pub fn newRenderPipelineState(self: *Self, descriptor: *MTLRenderPipelineDescriptor) !*MTLRenderPipelineState {
        var err: ?*ns.NSError = null;
        const pipeline = h.call(self, ?*MTLRenderPipelineState, "newRenderPipelineStateWithDescriptor:error:", .{ descriptor, &err });
        if (pipeline) |value| return value;

        if (err) |ns_error| ns_error.log() else if (!builtin.is_test)
            std.log.err("MTLDevice.newRenderPipelineState failed without NSError", .{});
        return error.NewRenderPipelineStateFailed;
    }
};

test "MTLDevice: newLibrary rejects invalid shader source" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init("this is not a Metal shader").?;
    defer source.release();
    try std.testing.expectError(error.NewLibraryFailed, device.newLibrary(source, null));
}

test "MTLDevice: newRenderPipelineState reports incompatible shader interfaces" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init(
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\struct VertexOutput { float4 position [[position]]; float2 coordinate [[user(locn0)]]; };
        \\vertex VertexOutput vertex_main() { return {float4(0), float2(0)}; }
        \\struct FragmentInput { float3 coordinate [[user(locn0)]]; };
        \\fragment float4 fragment_main(FragmentInput input [[stage_in]]) { return float4(input.coordinate, 1); }
    ).?;
    defer source.release();
    const library = try device.newLibrary(source, null);
    defer library.release();
    const vertex_name = ns.NSString.init("vertex_main").?;
    defer vertex_name.release();
    const vertex = library.newFunction(vertex_name).?;
    defer vertex.release();
    const fragment_name = ns.NSString.init("fragment_main").?;
    defer fragment_name.release();
    const fragment = library.newFunction(fragment_name).?;
    defer fragment.release();
    const descriptor = MTLRenderPipelineDescriptor.new();
    defer descriptor.release();
    descriptor.setVertexFunction(vertex);
    descriptor.setFragmentFunction(fragment);
    descriptor.colorAttachments().objectAtIndexedSubscript(0).setPixelFormat(mtl.MTLPixelFormatBGRA8Unorm);

    try std.testing.expectError(error.NewRenderPipelineStateFailed, device.newRenderPipelineState(descriptor));
}
