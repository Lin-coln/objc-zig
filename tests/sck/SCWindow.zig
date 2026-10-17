const objc = @import("objc");
const ns = @import("objc/ns");
const macos = @import("macos");
const SCRunningApplication = @import("SCRunningApplication.zig").SCRunningApplication;

pub const SCWindow = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const windowID = h.prop(macos.CGWindowID, "windowID").getter;
    pub const owningApplication = h.prop(?*SCRunningApplication, "owningApplication").getter;
    pub const title = h.prop(?*ns.NSString, "title").getter;
};
