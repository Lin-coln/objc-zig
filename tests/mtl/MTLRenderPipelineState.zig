const objc = @import("objc");

pub const MTLRenderPipelineState = opaque {
    const h = objc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
