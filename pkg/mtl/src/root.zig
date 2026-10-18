pub const c = @import("mtl-abi");

pub const MTLBlitCommandEncoder = @import("MTLBlitCommandEncoder.zig").MTLBlitCommandEncoder;
pub const MTLCommandBuffer = @import("MTLCommandBuffer.zig").MTLCommandBuffer;
pub const MTLCommandQueue = @import("MTLCommandQueue.zig").MTLCommandQueue;
pub const MTLCompileOptions = @import("MTLCompileOptions.zig").MTLCompileOptions;
pub const MTLDevice = @import("MTLDevice.zig").MTLDevice;
pub const MTLFunction = @import("MTLFunction.zig").MTLFunction;
pub const MTLLibrary = @import("MTLLibrary.zig").MTLLibrary;
pub const MTLRenderCommandEncoder = @import("MTLRenderCommandEncoder.zig").MTLRenderCommandEncoder;
pub const MTLRenderPassColorAttachmentDescriptor = @import("MTLRenderPassColorAttachmentDescriptor.zig").MTLRenderPassColorAttachmentDescriptor;
pub const MTLRenderPassColorAttachmentDescriptorArray = @import("MTLRenderPassColorAttachmentDescriptorArray.zig").MTLRenderPassColorAttachmentDescriptorArray;
pub const MTLRenderPassDescriptor = @import("MTLRenderPassDescriptor.zig").MTLRenderPassDescriptor;
pub const MTLRenderPipelineColorAttachmentDescriptor = @import("MTLRenderPipelineColorAttachmentDescriptor.zig").MTLRenderPipelineColorAttachmentDescriptor;
pub const MTLRenderPipelineColorAttachmentDescriptorArray = @import("MTLRenderPipelineColorAttachmentDescriptorArray.zig").MTLRenderPipelineColorAttachmentDescriptorArray;
pub const MTLRenderPipelineDescriptor = @import("MTLRenderPipelineDescriptor.zig").MTLRenderPipelineDescriptor;
pub const MTLRenderPipelineState = @import("MTLRenderPipelineState.zig").MTLRenderPipelineState;
pub const MTLTexture = @import("MTLTexture.zig").MTLTexture;
pub const MTLTextureDescriptor = @import("MTLTextureDescriptor.zig").MTLTextureDescriptor;

test {
    _ = @import("MTLBlitCommandEncoder.zig");
    _ = @import("MTLCommandBuffer.zig");
    _ = @import("MTLCommandQueue.zig");
    _ = @import("MTLCompileOptions.zig");
    _ = @import("MTLDevice.zig");
    _ = @import("MTLFunction.zig");
    _ = @import("MTLLibrary.zig");
    _ = @import("MTLRenderCommandEncoder.zig");
    _ = @import("MTLRenderPassColorAttachmentDescriptor.zig");
    _ = @import("MTLRenderPassColorAttachmentDescriptorArray.zig");
    _ = @import("MTLRenderPassDescriptor.zig");
    _ = @import("MTLRenderPipelineColorAttachmentDescriptor.zig");
    _ = @import("MTLRenderPipelineColorAttachmentDescriptorArray.zig");
    _ = @import("MTLRenderPipelineDescriptor.zig");
    _ = @import("MTLRenderPipelineState.zig");
    _ = @import("MTLTexture.zig");
    _ = @import("MTLTextureDescriptor.zig");
}
