const objc = @import("objc");
const ns = @import("objc/ns");
const MTLFunction = @import("MTLFunction.zig").MTLFunction;

pub const MTLLibrary = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an owned function, or null when the name is absent.
    pub const newFunction = h.method("newFunctionWithName:", fn (*ns.NSString) ?*MTLFunction);
};
