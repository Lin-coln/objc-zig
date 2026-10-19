const std = @import("std");
const obzc = @import("obzc");
const MTLRenderPipelineColorAttachmentDescriptor = @import("MTLRenderPipelineColorAttachmentDescriptor.zig").MTLRenderPipelineColorAttachmentDescriptor;

pub const MTLRenderPipelineColorAttachmentDescriptorArray = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns a borrowed attachment descriptor. The index must be in 0...7.
    pub const objectAtIndexedSubscript = h.method("objectAtIndexedSubscript:", fn (usize) *MTLRenderPipelineColorAttachmentDescriptor);
};

test "MTLRenderPipelineColorAttachmentDescriptorArray: indexed attachments keep independent values" {
    const mtl = @import("mtl-abi");
    const MTLRenderPipelineDescriptor = @import("MTLRenderPipelineDescriptor.zig").MTLRenderPipelineDescriptor;
    const descriptor = MTLRenderPipelineDescriptor.new();
    defer descriptor.release();
    const colors = descriptor.colorAttachments();
    const first = colors.objectAtIndexedSubscript(0);
    const second = colors.objectAtIndexedSubscript(1);

    first.setPixelFormat(mtl.MTLPixelFormatBGRA8Unorm);
    second.setPixelFormat(mtl.MTLPixelFormatRGBA16Float);
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatBGRA8Unorm), colors.objectAtIndexedSubscript(0).pixelFormat());
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatRGBA16Float), colors.objectAtIndexedSubscript(1).pixelFormat());
}
