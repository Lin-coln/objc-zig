const objc = @import("objc");
const mtl = @import("mtl-abi");
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLRenderPassColorAttachmentDescriptor = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const texture = h.prop(?*MTLTexture, "texture").getter;
    pub const setTexture = h.prop(?*MTLTexture, "texture").setter;
    pub const loadAction = h.prop(mtl.MTLLoadAction, "loadAction").getter;
    pub const setLoadAction = h.prop(mtl.MTLLoadAction, "loadAction").setter;
    pub const storeAction = h.prop(mtl.MTLStoreAction, "storeAction").getter;
    pub const setStoreAction = h.prop(mtl.MTLStoreAction, "storeAction").setter;
    pub const clearColor = h.prop(mtl.MTLClearColor, "clearColor").getter;
    pub const setClearColor = h.prop(mtl.MTLClearColor, "clearColor").setter;
};
