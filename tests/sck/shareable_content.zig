const std = @import("std");
const macos = @import("macos");
const sck = @import("objc/sck");
const SCShareableContent = sck.SCShareableContent;

test "SCShareableContent: getShareableContentSync returns retained content" {
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;

    const content = try SCShareableContent.getShareableContentSync();
    defer content.release();

    const windows = content.windows();
    for (0..windows.count()) |index| {
        const window = windows.objectAtIndex(index);
        try std.testing.expect(window.windowID() != macos.kCGNullWindowID);
        const frame = window.frame();
        try std.testing.expect(std.math.isFinite(frame.origin.x));
        try std.testing.expect(std.math.isFinite(frame.origin.y));
        try std.testing.expect(frame.size.width >= 0);
        try std.testing.expect(frame.size.height >= 0);
        if (window.owningApplication()) |application| {
            try std.testing.expect(std.unicode.utf8ValidateSlice(application.applicationName().utf8String()));
        }
        if (window.title()) |title| _ = title.length();
    }
}
