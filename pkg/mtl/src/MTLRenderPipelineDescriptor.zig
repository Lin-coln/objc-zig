const std = @import("std");
const obzc = @import("obzc");
const MTLFunction = @import("MTLFunction.zig").MTLFunction;
const MTLRenderPipelineColorAttachmentDescriptorArray = @import("MTLRenderPipelineColorAttachmentDescriptorArray.zig").MTLRenderPipelineColorAttachmentDescriptorArray;

pub const MTLRenderPipelineDescriptor = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const vertexFunction = h.prop(?*MTLFunction, "vertexFunction").getter;
    pub const setVertexFunction = h.prop(?*MTLFunction, "vertexFunction").setter;
    pub const fragmentFunction = h.prop(?*MTLFunction, "fragmentFunction").getter;
    pub const setFragmentFunction = h.prop(?*MTLFunction, "fragmentFunction").setter;
    /// Borrowed attachment array, owned by this descriptor.
    pub const colorAttachments = h.prop(*MTLRenderPipelineColorAttachmentDescriptorArray, "colorAttachments").getter;
    pub const hash = h.method("hash", fn () usize);
};

test "MTLRenderPipelineDescriptor: function slots accept null" {
    const descriptor = MTLRenderPipelineDescriptor.new();
    defer descriptor.release();

    try std.testing.expect(descriptor.vertexFunction() == null);
    try std.testing.expect(descriptor.fragmentFunction() == null);
    descriptor.setVertexFunction(null);
    descriptor.setFragmentFunction(null);
    try std.testing.expect(descriptor.vertexFunction() == null);
    try std.testing.expect(descriptor.fragmentFunction() == null);
}
