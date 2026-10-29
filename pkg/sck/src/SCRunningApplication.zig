const core = @import("core");
const Metadata = core.Metadata;
const ns = @import("obzc-ns");

pub const SCRunningApplication = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// The returned name is borrowed from the application.
    pub const applicationName = h.prop("applicationName", *ns.NSString).getter;
};
