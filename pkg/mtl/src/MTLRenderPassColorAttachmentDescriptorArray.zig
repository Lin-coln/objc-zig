const obzc = @import("obzc");
const MTLRenderPassColorAttachmentDescriptor = @import("MTLRenderPassColorAttachmentDescriptor.zig").MTLRenderPassColorAttachmentDescriptor;

pub const MTLRenderPassColorAttachmentDescriptorArray = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns a borrowed attachment descriptor. The index must be in 0...7.
    pub const objectAtIndexedSubscript = h.method("objectAtIndexedSubscript:", fn (usize) *MTLRenderPassColorAttachmentDescriptor);
};
