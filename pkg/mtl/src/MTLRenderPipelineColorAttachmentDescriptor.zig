const obzc = @import("obzc");
const mtl = @import("mtl-abi");

pub const MTLRenderPipelineColorAttachmentDescriptor = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const pixelFormat = h.prop(mtl.MTLPixelFormat, "pixelFormat").getter;
    pub const setPixelFormat = h.prop(mtl.MTLPixelFormat, "pixelFormat").setter;
};
