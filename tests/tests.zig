comptime {
    _ = @import("basic/runtime.zig");
    _ = @import("block_interop.zig");

    _ = @import("sck/shareable_content.zig");
    _ = @import("sck/stream.zig");

    _ = @import("mtl/MTLDevice.zig");
    _ = @import("mtl/MTLTextureDescriptor.zig");
    _ = @import("mtl/MTLRenderPipelineDescriptor.zig");
    _ = @import("mtl/MTLRenderPassDescriptor.zig");

    _ = @import("vision/VNRecognizeTextRequest.zig");
    _ = @import("vision/VNImageRequestHandler.zig");
}
