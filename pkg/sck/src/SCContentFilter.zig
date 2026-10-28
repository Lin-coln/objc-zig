const obzc = @import("obzc");
const Metadata = obzc.Metadata;
const SCWindow = @import("SCWindow.zig").SCWindow;

pub const SCContentFilter = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Creates an owned filter for the supplied desktop-independent window.
    pub fn init(window: *SCWindow) *Self {
        return h.call(h.cls.alloc(), *Self, "initWithDesktopIndependentWindow:", .{window});
    }
};
