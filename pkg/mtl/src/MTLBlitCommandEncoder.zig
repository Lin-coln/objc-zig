const obzc = @import("obzc");
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLBlitCommandEncoder = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const copyFromTexture = h.m.of("copyFromTexture:toTexture:", fn (*MTLTexture, *MTLTexture) void);
    pub const endEncoding = h.m.of("endEncoding", fn () void);
};
