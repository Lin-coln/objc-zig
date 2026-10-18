const objc = @import("objc");
const mtl = @import("macos/mtl-abi");

pub const MTLRenderPipelineColorAttachmentDescriptor = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const pixelFormat = h.prop(mtl.MTLPixelFormat, "pixelFormat").getter;
    pub const setPixelFormat = h.prop(mtl.MTLPixelFormat, "pixelFormat").setter;
};
