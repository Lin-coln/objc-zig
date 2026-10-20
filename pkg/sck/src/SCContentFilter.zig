const obzc = @import("obzc");
const SCWindow = @import("SCWindow.zig").SCWindow;

pub const SCContentFilter = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Creates an owned filter for the supplied desktop-independent window.
    pub fn init(window: *SCWindow) *Self {
        const initialize = h.m.of("initWithDesktopIndependentWindow:", fn (*SCWindow) *Self);
        return initialize(h.cls.alloc(), window);
    }
};
