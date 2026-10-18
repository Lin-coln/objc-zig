const objc = @import("objc");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const SCRunningApplication = @import("SCRunningApplication.zig").SCRunningApplication;

pub const SCWindow = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const windowID = h.prop(macos.CGWindowID, "windowID").getter;
    pub const frame = h.prop(macos.CGRect, "frame").getter;
    pub const owningApplication = h.prop(?*SCRunningApplication, "owningApplication").getter;
    pub const title = h.prop(?*ns.NSString, "title").getter;
};
