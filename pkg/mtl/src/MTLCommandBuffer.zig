const obzc = @import("obzc");
const ns = @import("obzc-ns");
const mtl = @import("mtl-abi");
const MTLRenderPassDescriptor = @import("MTLRenderPassDescriptor.zig").MTLRenderPassDescriptor;
const MTLRenderCommandEncoder = @import("MTLRenderCommandEncoder.zig").MTLRenderCommandEncoder;
const MTLBlitCommandEncoder = @import("MTLBlitCommandEncoder.zig").MTLBlitCommandEncoder;

pub const MTLCommandBuffer = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returned encoders are autoreleased and must finish before another encoder starts.
    pub const renderCommandEncoder = h.m.of("renderCommandEncoderWithDescriptor:", fn (*MTLRenderPassDescriptor) ?*MTLRenderCommandEncoder);
    pub const blitCommandEncoder = h.m.of("blitCommandEncoder", fn () ?*MTLBlitCommandEncoder);
    pub const commit = h.m.of("commit", fn () void);
    pub const waitUntilCompleted = h.m.of("waitUntilCompleted", fn () void);
    pub const status = h.m.of("status", fn () mtl.MTLCommandBufferStatus);
    /// Borrowed error describing a failed command buffer.
    pub const @"error" = h.m.of("error", fn () ?*ns.NSError);
};
