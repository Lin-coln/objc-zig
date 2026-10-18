const std = @import("std");
const macos = @import("macos");
const sck = @import("objc/sck");
const SCShareableContent = sck.SCShareableContent;
const SCContentFilter = sck.SCContentFilter;
const SCStreamConfiguration = sck.SCStreamConfiguration;
const SCStream = sck.SCStream;

test "SCStream: initialize and update configuration" {
    std.testing.refAllDecls(SCStream);
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;
    // Initialize CoreGraphics in this command-line test process before creating a filter.
    _ = macos.CGMainDisplayID();
    const content = try SCShareableContent.getShareableContentSync();
    defer content.release();
    const windows = content.windows();
    if (windows.count() == 0) return error.SkipZigTest;
    const filter = SCContentFilter.init(windows.objectAtIndex(0));
    defer filter.release();
    const configuration = SCStreamConfiguration.new();
    defer configuration.release();
    configuration.setWidth(128);
    configuration.setHeight(72);
    const stream = SCStream.init(filter, configuration, null);
    defer stream.release();
    configuration.setQueueDepth(4);
    try stream.updateConfigurationSync(configuration);
}
