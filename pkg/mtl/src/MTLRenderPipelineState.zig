const obzc = @import("obzc");

pub const MTLRenderPipelineState = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
};
