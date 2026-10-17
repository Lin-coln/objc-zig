const objc = @import("objc");

pub const SCRunningApplication = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
};
