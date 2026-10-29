const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;
const MTLFunction = @import("MTLFunction.zig").MTLFunction;
const MTLRenderPipelineColorAttachmentDescriptorArray = @import("MTLRenderPipelineColorAttachmentDescriptorArray.zig").MTLRenderPipelineColorAttachmentDescriptorArray;

pub const MTLRenderPipelineDescriptor = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const vertexFunction = h.prop("vertexFunction", ?*MTLFunction).getter;
    pub const setVertexFunction = h.prop("vertexFunction", ?*MTLFunction).setter;
    pub const fragmentFunction = h.prop("fragmentFunction", ?*MTLFunction).getter;
    pub const setFragmentFunction = h.prop("fragmentFunction", ?*MTLFunction).setter;
    /// Borrowed attachment array, owned by this descriptor.
    pub const colorAttachments = h.prop("colorAttachments", *MTLRenderPipelineColorAttachmentDescriptorArray).getter;
    pub const hash = h.method("hash", fn () usize);
};

test "MTLRenderPipelineDescriptor: new has empty function slots" {
    const descriptor = MTLRenderPipelineDescriptor.new();
    defer descriptor.release();

    try std.testing.expect(descriptor.vertexFunction() == null);
    try std.testing.expect(descriptor.fragmentFunction() == null);
}

test "MTLRenderPipelineDescriptor: function slots store and clear functions independently" {
    const ns = @import("ns");
    const MTLDevice = @import("MTLDevice.zig").MTLDevice;
    const pool = core.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init(
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\vertex float4 vertex_main() { return float4(0); }
        \\fragment float4 fragment_main() { return float4(1); }
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
    try std.testing.expectEqual(vertex, descriptor.vertexFunction().?);
    try std.testing.expectEqual(fragment, descriptor.fragmentFunction().?);
    descriptor.setVertexFunction(null);
    try std.testing.expect(descriptor.vertexFunction() == null);
    try std.testing.expectEqual(fragment, descriptor.fragmentFunction().?);
    descriptor.setFragmentFunction(null);
    try std.testing.expect(descriptor.fragmentFunction() == null);
}
