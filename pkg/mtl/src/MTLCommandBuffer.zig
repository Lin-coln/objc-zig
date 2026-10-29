const core = @import("core");
const Metadata = core.Metadata;
const ns = @import("obzc-ns");
const mtl = @import("mtl-abi");
const MTLRenderPassDescriptor = @import("MTLRenderPassDescriptor.zig").MTLRenderPassDescriptor;
const MTLRenderCommandEncoder = @import("MTLRenderCommandEncoder.zig").MTLRenderCommandEncoder;
const MTLBlitCommandEncoder = @import("MTLBlitCommandEncoder.zig").MTLBlitCommandEncoder;

pub const MTLCommandBuffer = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returned encoders are autoreleased and must finish before another encoder starts.
    pub const renderCommandEncoder = h.method("renderCommandEncoderWithDescriptor:", fn (*MTLRenderPassDescriptor) ?*MTLRenderCommandEncoder);
    pub const blitCommandEncoder = h.method("blitCommandEncoder", fn () ?*MTLBlitCommandEncoder);
    pub const commit = h.method("commit", fn () void);
    pub const waitUntilCompleted = h.method("waitUntilCompleted", fn () void);
    pub const status = h.method("status", fn () mtl.MTLCommandBufferStatus);
    /// Borrowed error describing a failed command buffer.
    pub const @"error" = h.method("error", fn () ?*ns.NSError);
};
