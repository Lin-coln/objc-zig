const std = @import("std");
const objc = @import("objc");
const mtl = @import("macos/mtl-abi");
const MTLFunction = @import("MTLFunction.zig").MTLFunction;
const MTLRenderPipelineColorAttachmentDescriptorArray = @import("MTLRenderPipelineColorAttachmentDescriptorArray.zig").MTLRenderPipelineColorAttachmentDescriptorArray;

pub const MTLRenderPipelineDescriptor = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

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

test "MTLRenderPipelineDescriptor: function slots and indexed color attachments" {
    const descriptor = MTLRenderPipelineDescriptor.new();
    defer descriptor.release();

    try std.testing.expect(descriptor.vertexFunction() == null);
    try std.testing.expect(descriptor.fragmentFunction() == null);
    descriptor.setVertexFunction(null);
    descriptor.setFragmentFunction(null);

    const colors = descriptor.colorAttachments();
    const first = colors.objectAtIndexedSubscript(0);
    const second = colors.objectAtIndexedSubscript(1);
    first.setPixelFormat(mtl.MTLPixelFormatBGRA8Unorm);
    second.setPixelFormat(mtl.MTLPixelFormatRGBA16Float);
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatBGRA8Unorm), first.pixelFormat());
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatRGBA16Float), second.pixelFormat());
}
