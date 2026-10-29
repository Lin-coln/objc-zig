const std = @import("std");
pub const SCStreamConfiguration = @import("SCStreamConfiguration.zig").SCStreamConfiguration;
pub const SCCaptureResolutionType = @import("SCStreamConfiguration.zig").SCCaptureResolutionType;
pub const SCShareableContent = @import("SCShareableContent.zig").SCShareableContent;
pub const SCWindow = @import("SCWindow.zig").SCWindow;
pub const SCRunningApplication = @import("SCRunningApplication.zig").SCRunningApplication;
pub const SCContentFilter = @import("SCContentFilter.zig").SCContentFilter;
pub const SCStream = @import("SCStream.zig").SCStream;
pub const SCStreamOutputType = @import("SCStream.zig").SCStreamOutputType;
pub const SCStreamDelegate = @import("SCStreamDelegate.zig").SCStreamDelegate;
pub const SCStreamOutput = @import("SCStreamOutput.zig").SCStreamOutput;

test {
    std.testing.refAllDecls(@This());
}
