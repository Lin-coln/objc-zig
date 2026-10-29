const core = @import("core");
const Metadata = core.Metadata;

pub const MTLRenderPipelineState = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
};
