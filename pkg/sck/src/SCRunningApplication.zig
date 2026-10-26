const obzc = @import("obzc");
const ns = @import("obzc-ns");

pub const SCRunningApplication = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// The returned name is borrowed from the application.
    pub const applicationName = h.prop("applicationName", *ns.NSString).getter;
};
