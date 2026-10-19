const std = @import("std");
const rt = @import("obzc").rt;
const macos = @import("macos/abi");
const sck = @import("obzc-sck");

const ObzcSCKStreamOutputTest = opaque {
    const Self = @This();
    const callback_selector = "stream:didOutputSampleBuffer:ofType:";

    const Context = struct {
        calls: usize = 0,
        stream: ?*sck.SCStream = null,
        sample_buffer: macos.CMSampleBufferRef = null,
        output_type: ?sck.SCStreamOutputType = null,
    };

    /// The caller must release every instance before disposing the registered class.
    pub fn registerClass() !*rt.Class {
        const cls = rt.allocateClassPair(rt.getClass("NSObject").?, "ObzcSCKStreamOutputTest", 0) orelse return error.ClassAllocFailed;
        errdefer rt.disposeClassPair(cls);

        // The SDK may omit protocol metadata; its add/remove operations are tested regardless.
        if (rt.getProtocol("SCStreamOutput")) |protocol| {
            if (!cls.addProtocol(protocol)) return error.AddProtocolFailed;
        }
        if (!cls.addIvar("_context", @sizeOf(*Context), std.math.log2_int(usize, @alignOf(*Context)), "^v"))
            return error.AddContextFailed;
        // SCStream *, CMSampleBufferRef and SCStreamOutputType (NSInteger), from SCStream.h.
        if (!cls.addMethod(rt.Sel.registerName(callback_selector), &receive, "v@:@^{opaqueCMSampleBuffer=}q"))
            return error.AddCallbackFailed;
        rt.registerClassPair(cls);
        return cls;
    }

    /// The context is borrowed and must outlive the instance and every callback.
    pub fn new(cls: *rt.Class, context: *Context) *Self {
        const self = rt.msgSend(cls, ?*Self, rt.Sel.registerName("new"), .{}).?;
        const object: *rt.Object = @ptrCast(self);
        _ = object.setInstanceVariable("_context", context).?;
        return self;
    }

    pub fn release(self: *Self) void {
        rt.release(@ptrCast(self));
    }

    pub fn asOutput(self: *Self) *sck.SCStreamOutput {
        return @ptrCast(self);
    }

    pub fn didOutputSampleBuffer(self: *Self, stream: *sck.SCStream, sample_buffer: macos.CMSampleBufferRef, output_type: sck.SCStreamOutputType) void {
        rt.msgSend(self, void, rt.Sel.registerName(callback_selector), .{ stream, sample_buffer, output_type });
    }

    fn receive(self: *rt.Object, _: *rt.Sel, stream: *sck.SCStream, sample_buffer: macos.CMSampleBufferRef, output_type: sck.SCStreamOutputType) callconv(.c) void {
        var raw: ?*anyopaque = null;
        _ = self.getInstanceVariable("_context", &raw).?;
        const context: *Context = @ptrCast(@alignCast(raw.?));
        context.calls += 1;
        context.stream = stream;
        context.sample_buffer = sample_buffer;
        context.output_type = output_type;
    }
};

// These SDK objects are shared by the registration and message-dispatch checks.
const Fixture = struct {
    filter: *sck.SCContentFilter,
    configuration: *sck.SCStreamConfiguration,
    stream: *sck.SCStream,
    sample_buffer: macos.CMSampleBufferRef,

    fn init() !Fixture {
        // An empty filter allows stream initialization without starting capture.
        const filter = rt.msgSend(rt.getClass("SCContentFilter").?, ?*sck.SCContentFilter, rt.Sel.registerName("new"), .{}).?;
        errdefer filter.release();
        const configuration = sck.SCStreamConfiguration.new();
        errdefer configuration.release();
        const stream = sck.SCStream.init(filter, configuration, null);
        errdefer stream.release();
        var sample_buffer: macos.CMSampleBufferRef = null;
        if (macos.CMSampleBufferCreate(null, null, 1, null, null, null, 0, 0, null, 0, null, &sample_buffer) != 0)
            return error.SampleBufferCreateFailed;
        return .{ .filter = filter, .configuration = configuration, .stream = stream, .sample_buffer = sample_buffer.? };
    }

    fn deinit(self: Fixture) void {
        macos.CFRelease(self.sample_buffer);
        self.stream.release();
        self.configuration.release();
        self.filter.release();
    }
};

test "SCStreamOutput: SDK registration and per-instance callback contexts" {
    const cls = try ObzcSCKStreamOutputTest.registerClass();
    defer rt.disposeClassPair(cls);
    try std.testing.expect(cls.respondsToSelector(rt.Sel.registerName(ObzcSCKStreamOutputTest.callback_selector)));
    if (rt.getProtocol("SCStreamOutput")) |protocol| try std.testing.expect(cls.conformsToProtocol(protocol));

    var first_context: ObzcSCKStreamOutputTest.Context = .{};
    var second_context: ObzcSCKStreamOutputTest.Context = .{};
    // Destroy the stream before its output objects, even when removing an output fails.
    const first = ObzcSCKStreamOutputTest.new(cls, &first_context);
    defer first.release();
    const second = ObzcSCKStreamOutputTest.new(cls, &second_context);
    defer second.release();
    const fixture = try Fixture.init();
    defer fixture.deinit();

    try fixture.stream.addStreamOutput(first.asOutput(), .screen, null);
    // Exercise the registered IMP through message dispatch, without waiting for captured frames.
    first.didOutputSampleBuffer(fixture.stream, fixture.sample_buffer, .screen);
    second.didOutputSampleBuffer(fixture.stream, fixture.sample_buffer, .audio);
    try fixture.stream.removeStreamOutput(first.asOutput(), .screen);

    try std.testing.expectEqual(1, first_context.calls);
    try std.testing.expectEqual(1, second_context.calls);
    for ([_]*ObzcSCKStreamOutputTest.Context{ &first_context, &second_context }) |context| {
        try std.testing.expectEqual(fixture.stream, context.stream.?);
        try std.testing.expectEqual(fixture.sample_buffer, context.sample_buffer);
    }
    try std.testing.expectEqual(sck.SCStreamOutputType.screen, first_context.output_type.?);
    try std.testing.expectEqual(sck.SCStreamOutputType.audio, second_context.output_type.?);
}
