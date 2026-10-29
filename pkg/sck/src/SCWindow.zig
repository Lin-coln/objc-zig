const core = @import("core");
const Metadata = core.Metadata;
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const SCRunningApplication = @import("SCRunningApplication.zig").SCRunningApplication;

pub const SCWindow = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const windowID = h.prop("windowID", macos.CGWindowID).getter;
    pub const frame = h.prop("frame", macos.CGRect).getter;
    pub const owningApplication = h.prop("owningApplication", ?*SCRunningApplication).getter;
    pub const title = h.prop("title", ?*ns.NSString).getter;
};
