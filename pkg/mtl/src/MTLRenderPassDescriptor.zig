const obzc = @import("obzc");
const MTLRenderPassColorAttachmentDescriptorArray = @import("MTLRenderPassColorAttachmentDescriptorArray.zig").MTLRenderPassColorAttachmentDescriptorArray;

pub const MTLRenderPassDescriptor = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    /// Borrowed attachment array, owned by this descriptor.
    pub const colorAttachments = h.prop(*MTLRenderPassColorAttachmentDescriptorArray, "colorAttachments").getter;
};
