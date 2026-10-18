const objc = @import("objc");
const mtl = @import("macos/mtl-abi");

pub const MTLFunction = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const functionType = h.method("functionType", fn () mtl.MTLFunctionType);
};
