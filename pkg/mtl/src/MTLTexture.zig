const objc = @import("objc");
const mtl = @import("mtl-abi");
const MTLDevice = @import("MTLDevice.zig").MTLDevice;

pub const MTLTexture = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const width = h.method("width", fn () usize);
    pub const height = h.method("height", fn () usize);
    pub const pixelFormat = h.method("pixelFormat", fn () mtl.MTLPixelFormat);
    /// Borrowed device that created this texture.
    pub const device = h.method("device", fn () *MTLDevice);
};
