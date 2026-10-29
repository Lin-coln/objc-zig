const std = @import("std");
const core = @import("core");
const macos = @import("macos/abi");
const sck = @import("sck");
const SCShareableContent = sck.SCShareableContent;
const SCContentFilter = sck.SCContentFilter;
const SCStreamConfiguration = sck.SCStreamConfiguration;
const SCStream = sck.SCStream;

test "SCStream: update a window capture stream with a new configuration" {
    // Compile the remaining bindings without starting a capture session.
    std.testing.refAllDecls(SCStream);
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;
    const pool = core.AutoReleasePool.create();
    defer pool.release();
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
    const updated = SCStreamConfiguration.new();
    defer updated.release();
    updated.setWidth(256);
    updated.setHeight(144);
    updated.setQueueDepth(4);
    try stream.updateConfigurationSync(updated);
}
