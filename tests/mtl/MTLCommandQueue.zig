const objc = @import("objc");
const MTLCommandBuffer = @import("MTLCommandBuffer.zig").MTLCommandBuffer;

pub const MTLCommandQueue = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an autoreleased command buffer, or null on allocation failure.
    pub const commandBuffer = h.method("commandBuffer", fn () ?*MTLCommandBuffer);
};
