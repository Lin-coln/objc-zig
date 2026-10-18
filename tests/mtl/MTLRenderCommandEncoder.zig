const objc = @import("objc");
const mtl = @import("macos/mtl-abi");
const MTLRenderPipelineState = @import("MTLRenderPipelineState.zig").MTLRenderPipelineState;
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLRenderCommandEncoder = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const setRenderPipelineState = h.method("setRenderPipelineState:", fn (*MTLRenderPipelineState) void);
    pub const setVertexBytes = h.method("setVertexBytes:length:atIndex:", fn (*const anyopaque, usize, usize) void);
    pub const setFragmentTexture = h.method("setFragmentTexture:atIndex:", fn (?*MTLTexture, usize) void);
    pub const drawPrimitives = h.method("drawPrimitives:vertexStart:vertexCount:", fn (mtl.MTLPrimitiveType, usize, usize) void);
    pub const endEncoding = h.method("endEncoding", fn () void);
};
