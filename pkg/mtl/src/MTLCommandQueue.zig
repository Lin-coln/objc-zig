const obzc = @import("obzc");
const Metadata = obzc.Metadata;
const MTLCommandBuffer = @import("MTLCommandBuffer.zig").MTLCommandBuffer;

pub const MTLCommandQueue = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an autoreleased command buffer, or null on allocation failure.
    pub const commandBuffer = h.method("commandBuffer", fn () ?*MTLCommandBuffer);
};
