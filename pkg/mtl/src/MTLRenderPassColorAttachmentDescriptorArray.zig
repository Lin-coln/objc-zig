const std = @import("std");
const obzc = @import("obzc");
const Metadata = obzc.Metadata;
const MTLRenderPassColorAttachmentDescriptor = @import("MTLRenderPassColorAttachmentDescriptor.zig").MTLRenderPassColorAttachmentDescriptor;

pub const MTLRenderPassColorAttachmentDescriptorArray = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns a borrowed attachment descriptor. The index must be in 0...7.
    pub const objectAtIndexedSubscript = h.method("objectAtIndexedSubscript:", fn (usize) *MTLRenderPassColorAttachmentDescriptor);
};

test "MTLRenderPassColorAttachmentDescriptorArray: indexed attachments keep independent values" {
    const mtl = @import("mtl-abi");
    const MTLRenderPassDescriptor = @import("MTLRenderPassDescriptor.zig").MTLRenderPassDescriptor;
    const descriptor = MTLRenderPassDescriptor.new();
    defer descriptor.release();
    const colors = descriptor.colorAttachments();
    const first = colors.objectAtIndexedSubscript(0);
    const second = colors.objectAtIndexedSubscript(1);

    first.setLoadAction(mtl.MTLLoadActionClear);
    second.setLoadAction(mtl.MTLLoadActionLoad);
    try std.testing.expectEqual(@as(mtl.MTLLoadAction, mtl.MTLLoadActionClear), colors.objectAtIndexedSubscript(0).loadAction());
    try std.testing.expectEqual(@as(mtl.MTLLoadAction, mtl.MTLLoadActionLoad), colors.objectAtIndexedSubscript(1).loadAction());
}
