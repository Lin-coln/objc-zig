const obzc = @import("obzc");
const SCWindow = @import("SCWindow.zig").SCWindow;

pub const SCContentFilter = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Creates an owned filter for the supplied desktop-independent window.
    pub fn init(window: *SCWindow) *Self {
        return h.call(h.cls.alloc(), *Self, "initWithDesktopIndependentWindow:", .{window});
    }
};
