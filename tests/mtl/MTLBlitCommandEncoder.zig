const objc = @import("objc");
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLBlitCommandEncoder = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const copyFromTexture = h.method("copyFromTexture:toTexture:", fn (*MTLTexture, *MTLTexture) void);
    pub const endEncoding = h.method("endEncoding", fn () void);
};
