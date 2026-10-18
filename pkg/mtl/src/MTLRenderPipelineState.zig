const obzc = @import("obzc");

pub const MTLRenderPipelineState = opaque {
    const h = obzc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
