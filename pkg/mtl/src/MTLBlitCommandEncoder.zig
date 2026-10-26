const obzc = @import("obzc");
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLBlitCommandEncoder = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const copyFromTexture = h.method("copyFromTexture:toTexture:", fn (*MTLTexture, *MTLTexture) void);
    pub const endEncoding = h.method("endEncoding", fn () void);
};
