const std = @import("std");
const obzc = @import("obzc");
const macos = @import("macos/abi");

/// SCCaptureResolutionType from ScreenCaptureKit/SCStream.h.
pub const SCCaptureResolutionType = enum(isize) {
    automatic = 0,
    best = 1,
    nominal = 2,
};

pub const SCStreamConfiguration = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const new = h.cls.new;
    pub const retain = h.retain;
    pub const release = h.release;

    pub const width = h.prop(usize, "width").getter;
    pub const setWidth = h.prop(usize, "width").setter;
    pub const height = h.prop(usize, "height").getter;
    pub const setHeight = h.prop(usize, "height").setter;
    pub const queueDepth = h.prop(isize, "queueDepth").getter;
    pub const setQueueDepth = h.prop(isize, "queueDepth").setter;
    pub const showsCursor = h.prop(bool, "showsCursor").getter;
    pub const setShowsCursor = h.prop(bool, "showsCursor").setter;
    pub const capturesAudio = h.prop(bool, "capturesAudio").getter;
    pub const setCapturesAudio = h.prop(bool, "capturesAudio").setter;
    pub const minimumFrameInterval = h.prop(macos.CMTime, "minimumFrameInterval").getter;
    pub const setMinimumFrameInterval = h.prop(macos.CMTime, "minimumFrameInterval").setter;
    pub const pixelFormat = h.prop(macos.OSType, "pixelFormat").getter;
    pub const setPixelFormat = h.prop(macos.OSType, "pixelFormat").setter;
    pub const captureResolution = h.prop(SCCaptureResolutionType, "captureResolution").getter;
    pub const setCaptureResolution = h.prop(SCCaptureResolutionType, "captureResolution").setter;
    /// Borrowed CoreFoundation references.
    pub const colorSpaceName = h.prop(macos.CFStringRef, "colorSpaceName").getter;
    pub const setColorSpaceName = h.prop(macos.CFStringRef, "colorSpaceName").setter;
    pub const backgroundColor = h.prop(macos.CGColorRef, "backgroundColor").getter;
    pub const setBackgroundColor = h.prop(macos.CGColorRef, "backgroundColor").setter;
};

test "SCStreamConfiguration: configure video and audio properties" {
    const configuration = SCStreamConfiguration.new();
    defer configuration.release();

    configuration.setWidth(1280);
    configuration.setHeight(720);
    configuration.setQueueDepth(4);
    configuration.setShowsCursor(false);
    configuration.setCapturesAudio(true);

    try std.testing.expectEqual(1280, configuration.width());
    try std.testing.expectEqual(720, configuration.height());
    try std.testing.expectEqual(4, configuration.queueDepth());
    try std.testing.expectEqual(false, configuration.showsCursor());
    try std.testing.expectEqual(true, configuration.capturesAudio());
}

test "SCStreamConfiguration: time, pixel format, resolution and color properties" {
    const configuration = SCStreamConfiguration.new();
    defer configuration.release();

    const interval = macos.CMTimeMake(1, 60);
    configuration.setMinimumFrameInterval(interval);
    const actual = configuration.minimumFrameInterval();
    try std.testing.expectEqual(interval.value, actual.value);
    try std.testing.expectEqual(interval.timescale, actual.timescale);
    try std.testing.expectEqual(interval.flags, actual.flags);
    try std.testing.expectEqual(interval.epoch, actual.epoch);

    configuration.setPixelFormat(macos.kCVPixelFormatType_64RGBAHalf);
    configuration.setCaptureResolution(.nominal);
    try std.testing.expectEqual(@as(macos.OSType, macos.kCVPixelFormatType_64RGBAHalf), configuration.pixelFormat());
    try std.testing.expectEqual(SCCaptureResolutionType.nominal, configuration.captureResolution());

    configuration.setColorSpaceName(macos.kCGColorSpaceDisplayP3);
    const color = macos.CGColorGetConstantColor(macos.kCGColorClear);
    configuration.setBackgroundColor(color);
    try std.testing.expect(macos.CFEqual(macos.kCGColorSpaceDisplayP3, configuration.colorSpaceName()) != 0);
    try std.testing.expect(macos.CGColorEqualToColor(color, configuration.backgroundColor()));
}
