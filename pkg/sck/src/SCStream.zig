const std = @import("std");
const builtin = @import("builtin");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
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
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Creates an owned stream. The delegate is optional and borrowed by this call.
    pub fn init(filter: *SCContentFilter, configuration: *SCStreamConfiguration, delegate: ?*SCStreamDelegate) *Self {
        return h.call(h.cls.alloc(), *Self, "initWithFilter:configuration:delegate:", .{ filter, configuration, delegate });
    }

    /// Adds an output, logging the SDK error on failure.
    pub fn addStreamOutput(self: *Self, output: *SCStreamOutput, output_type: SCStreamOutputType, sample_handler_queue: ?dispatch.queue_t) !void {
        var err: ?*ns.NSError = null;
        const succeeded = h.call(self, bool, "addStreamOutput:type:sampleHandlerQueue:error:", .{ output, output_type, sample_handler_queue, &err });
        if (succeeded) return;

        if (err) |ns_error| ns_error.log() else if (!builtin.is_test)
            std.log.err("SCStream.addStreamOutput failed without NSError", .{});
        return error.AddStreamOutputFailed;
    }

    /// Removes an output, logging the SDK error on failure.
    pub fn removeStreamOutput(self: *Self, output: *SCStreamOutput, output_type: SCStreamOutputType) !void {
        var err: ?*ns.NSError = null;
        const succeeded = h.call(self, bool, "removeStreamOutput:type:error:", .{ output, output_type, &err });
        if (succeeded) return;

        if (err) |ns_error| ns_error.log() else if (!builtin.is_test)
            std.log.err("SCStream.removeStreamOutput failed without NSError", .{});
        return error.RemoveStreamOutputFailed;
    }

    pub const startCapture = h.m.withCallback("startCaptureWithCompletionHandler:", fn (fn (?*ns.NSError) void) void);
    pub const stopCapture = h.m.withCallback("stopCaptureWithCompletionHandler:", fn (fn (?*ns.NSError) void) void);
    pub const updateConfiguration = h.m.withCallback("updateConfiguration:completionHandler:", fn (*SCStreamConfiguration, fn (?*ns.NSError) void) void);

    /// Waits for completion. The calling thread must not be needed to deliver the callback.
    pub const startCaptureSync = h.m.withSync("startCaptureWithCompletionHandler:", fn () anyerror!void);
    pub const stopCaptureSync = h.m.withSync("stopCaptureWithCompletionHandler:", fn () anyerror!void);
    pub const updateConfigurationSync = h.m.withSync("updateConfiguration:completionHandler:", fn (*SCStreamConfiguration) anyerror!void);
};
