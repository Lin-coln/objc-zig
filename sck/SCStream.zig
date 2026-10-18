const std = @import("std");
const objc = @import("objc");
const ns = @import("objc/ns");
const SCContentFilter = @import("SCContentFilter.zig").SCContentFilter;
const SCStreamConfiguration = @import("SCStreamConfiguration.zig").SCStreamConfiguration;
const SCStreamDelegate = @import("SCStreamDelegate.zig").SCStreamDelegate;
const SCStreamOutput = @import("SCStreamOutput.zig").SCStreamOutput;
const dispatch = std.c.dispatch;

/// SCStreamOutputType from ScreenCaptureKit/SCStream.h.
pub const SCStreamOutputType = enum(isize) {
    screen = 0,
    audio = 1,
    microphone = 2,
};

pub const SCStream = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Creates an owned stream. The delegate is optional and borrowed by this call.
    pub fn init(filter: *SCContentFilter, configuration: *SCStreamConfiguration, delegate: ?*SCStreamDelegate) *Self {
        const initialize = h.method("initWithFilter:configuration:delegate:", fn (*SCContentFilter, *SCStreamConfiguration, ?*SCStreamDelegate) *Self);
        return initialize(h.cls.alloc(), filter, configuration, delegate);
    }

    /// On failure, err receives a borrowed NSError when supplied by the SDK.
    pub fn addStreamOutput(self: *Self, output: *SCStreamOutput, output_type: SCStreamOutputType, sample_handler_queue: ?dispatch.queue_t, err: ?*?*ns.NSError) bool {
        const add = h.method("addStreamOutput:type:sampleHandlerQueue:error:", fn (*SCStreamOutput, SCStreamOutputType, ?dispatch.queue_t, ?*?*ns.NSError) objc.c.BOOL);
        return objc.utils.cast.bool(add(self, output, output_type, sample_handler_queue, err));
    }

    /// On failure, err receives a borrowed NSError when supplied by the SDK.
    pub fn removeStreamOutput(self: *Self, output: *SCStreamOutput, output_type: SCStreamOutputType, err: ?*?*ns.NSError) bool {
        const remove = h.method("removeStreamOutput:type:error:", fn (*SCStreamOutput, SCStreamOutputType, ?*?*ns.NSError) objc.c.BOOL);
        return objc.utils.cast.bool(remove(self, output, output_type, err));
    }

    pub const startCapture = h.methodWithCallback("startCaptureWithCompletionHandler:", fn (fn (?*ns.NSError) void) void);
    pub const stopCapture = h.methodWithCallback("stopCaptureWithCompletionHandler:", fn (fn (?*ns.NSError) void) void);
    pub const updateConfiguration = h.methodWithCallback("updateConfiguration:completionHandler:", fn (*SCStreamConfiguration, fn (?*ns.NSError) void) void);

    /// Waits for completion. The calling thread must not be needed to deliver the callback.
    pub const startCaptureSync = h.methodSync("startCaptureWithCompletionHandler:", fn () anyerror!void);
    pub const stopCaptureSync = h.methodSync("stopCaptureWithCompletionHandler:", fn () anyerror!void);
    pub const updateConfigurationSync = h.methodSync("updateConfiguration:completionHandler:", fn (*SCStreamConfiguration) anyerror!void);
};
