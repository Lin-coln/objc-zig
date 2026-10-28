const obzc = @import("obzc");
const Metadata = obzc.Metadata;
const MTLRenderPassColorAttachmentDescriptorArray = @import("MTLRenderPassColorAttachmentDescriptorArray.zig").MTLRenderPassColorAttachmentDescriptorArray;

pub const MTLRenderPassDescriptor = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    /// Borrowed attachment array, owned by this descriptor.
    pub const colorAttachments = h.prop("colorAttachments", *MTLRenderPassColorAttachmentDescriptorArray).getter;
};
