const std = @import("std");
const obzc = @import("obzc");
const mtl = @import("mtl-abi");

pub const MTLRenderPipelineColorAttachmentDescriptor = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const pixelFormat = h.prop("pixelFormat", mtl.MTLPixelFormat).getter;
    pub const setPixelFormat = h.prop("pixelFormat", mtl.MTLPixelFormat).setter;
};

test "MTLRenderPipelineColorAttachmentDescriptor: pixelFormat can be changed" {
    const descriptor = MTLRenderPipelineColorAttachmentDescriptor.new();
    defer descriptor.release();

    descriptor.setPixelFormat(mtl.MTLPixelFormatBGRA8Unorm);
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatBGRA8Unorm), descriptor.pixelFormat());
    descriptor.setPixelFormat(mtl.MTLPixelFormatRGBA16Float);
    try std.testing.expectEqual(@as(mtl.MTLPixelFormat, mtl.MTLPixelFormatRGBA16Float), descriptor.pixelFormat());
}
