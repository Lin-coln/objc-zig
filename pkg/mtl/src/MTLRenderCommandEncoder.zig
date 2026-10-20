const obzc = @import("obzc");
const mtl = @import("mtl-abi");
const MTLRenderPipelineState = @import("MTLRenderPipelineState.zig").MTLRenderPipelineState;
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLRenderCommandEncoder = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const setRenderPipelineState = h.m.of("setRenderPipelineState:", fn (*MTLRenderPipelineState) void);
    pub const setVertexBytes = h.m.of("setVertexBytes:length:atIndex:", fn (*const anyopaque, usize, usize) void);
    pub const setFragmentTexture = h.m.of("setFragmentTexture:atIndex:", fn (?*MTLTexture, usize) void);
    pub const drawPrimitives = h.m.of("drawPrimitives:vertexStart:vertexCount:", fn (mtl.MTLPrimitiveType, usize, usize) void);
    pub const endEncoding = h.m.of("endEncoding", fn () void);
};
