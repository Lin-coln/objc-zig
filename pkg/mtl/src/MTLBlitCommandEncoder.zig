const core = @import("core");
const Metadata = core.Metadata;
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLBlitCommandEncoder = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const copyFromTexture = h.method("copyFromTexture:toTexture:", fn (*MTLTexture, *MTLTexture) void);
    pub const endEncoding = h.method("endEncoding", fn () void);
};
