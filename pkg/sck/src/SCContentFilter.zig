const std = @import("std");
const objc = @import("objc");
const macos = @import("macos/abi");
const SCWindow = @import("SCWindow.zig").SCWindow;
const SCShareableContent = @import("SCShareableContent.zig").SCShareableContent;

pub const SCContentFilter = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Creates an owned filter for the supplied desktop-independent window.
    pub fn init(window: *SCWindow) *Self {
        const initialize = h.method("initWithDesktopIndependentWindow:", fn (*SCWindow) *Self);
        return initialize(h.cls.alloc(), window);
    }
};

test "SCContentFilter: initialize with a shareable window" {
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;
    // Initialize CoreGraphics in this command-line test process before creating a filter.
    _ = macos.CGMainDisplayID();
    const content = try SCShareableContent.getShareableContentSync();
    defer content.release();
    const windows = content.windows();
    if (windows.count() == 0) return error.SkipZigTest;

    const filter = SCContentFilter.init(windows.objectAtIndex(0));
    defer filter.release();
    const retained = filter.retain();
    defer retained.release();
    try std.testing.expectEqual(filter, retained);
}
