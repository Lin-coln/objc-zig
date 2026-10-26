const std = @import("std");
const obzc = @import("obzc");
const ffi = obzc.ffi;
const c = ffi.c;
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
    pub fn registerClass() !*ffi.Class {
        const cls = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcSCKStreamOutputTest", 0) orelse return error.ClassAllocFailed;
        errdefer c.objc_disposeClassPair(@ptrCast(cls));

        // The SDK may omit protocol metadata; its add/remove operations are tested regardless.
        if (c.objc_getProtocol("SCStreamOutput")) |protocol| {
            if (c.class_addProtocol(cls, protocol) != c.YES) return error.AddProtocolFailed;
        }
        if (c.class_addIvar(cls, "_context", @sizeOf(*Context), std.math.log2_int(usize, @alignOf(*Context)), "^v") != c.YES)
            return error.AddContextFailed;
        // SCStream *, CMSampleBufferRef and SCStreamOutputType (NSInteger), from SCStream.h.
        if (c.class_addMethod(cls, c.sel_registerName(callback_selector), @ptrCast(&receive), "v@:@^{opaqueCMSampleBuffer=}q") != c.YES)
            return error.AddCallbackFailed;
        c.objc_registerClassPair(cls);
        return @ptrCast(cls);
    }

    /// The context is borrowed and must outlive the instance and every callback.
    pub fn new(cls: *ffi.Class, context: *Context) *Self {
        const self = ffi.msg.send(cls, ?*Self, ffi.Sel.get("new"), .{}).?;
        _ = c.object_setInstanceVariable(@ptrCast(self), "_context", context).?;
        return self;
    }

    pub fn release(self: *Self) void {
        c.objc_release(@ptrCast(self));
    }

    pub fn asOutput(self: *Self) *sck.SCStreamOutput {
        return @ptrCast(self);
    }

    pub fn didOutputSampleBuffer(self: *Self, stream: *sck.SCStream, sample_buffer: macos.CMSampleBufferRef, output_type: sck.SCStreamOutputType) void {
        ffi.msg.send(self, void, ffi.Sel.get(callback_selector), .{ stream, sample_buffer, output_type });
    }

    fn receive(self: *ffi.Object, _: *ffi.Sel, stream: *sck.SCStream, sample_buffer: macos.CMSampleBufferRef, output_type: sck.SCStreamOutputType) callconv(.c) void {
        var raw: ?*anyopaque = null;
        _ = c.object_getInstanceVariable(@ptrCast(self), "_context", &raw).?;
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
        const filter = ffi.msg.send(ffi.Class.lookup("SCContentFilter").?, ?*sck.SCContentFilter, ffi.Sel.get("new"), .{}).?;
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
    defer c.objc_disposeClassPair(@ptrCast(cls));
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    try std.testing.expect(c.class_respondsToSelector(@ptrCast(cls), c.sel_registerName(ObzcSCKStreamOutputTest.callback_selector)) == c.YES);
    if (c.objc_getProtocol("SCStreamOutput")) |protocol| try std.testing.expect(c.class_conformsToProtocol(@ptrCast(cls), protocol) == c.YES);

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
    try std.testing.expectError(error.RemoveStreamOutputFailed, fixture.stream.removeStreamOutput(first.asOutput(), .screen));

    try std.testing.expectEqual(1, first_context.calls);
    try std.testing.expectEqual(1, second_context.calls);
    for ([_]*ObzcSCKStreamOutputTest.Context{ &first_context, &second_context }) |context| {
        try std.testing.expectEqual(fixture.stream, context.stream.?);
        try std.testing.expectEqual(fixture.sample_buffer, context.sample_buffer);
    }
    try std.testing.expectEqual(sck.SCStreamOutputType.screen, first_context.output_type.?);
    try std.testing.expectEqual(sck.SCStreamOutputType.audio, second_context.output_type.?);
}
