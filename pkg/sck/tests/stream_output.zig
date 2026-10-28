const std = @import("std");
const obzc = @import("obzc");
const macos = @import("macos/abi");
const sck = @import("obzc-sck");

const ffi = obzc.ffi;
const c = ffi.c;
const Class = ffi.Class;

const Context = struct {
    calls: usize = 0,
    stream: ?*sck.SCStream = null,
    sample_buffer: macos.CMSampleBufferRef = null,
    output_type: ?sck.SCStreamOutputType = null,
};

const SCKStreamOutputTest = opaque {
    const Self = @This();
    const h = obzc.h(Self);
    pub const release = h.release;
    pub const context = h.ivar("context", *Context).getter;
    pub const setContext = h.ivar("context", *Context).setter;

    /// The caller must release every instance before disposing the registered class.
    pub fn registerClass() !*Class {
        const cls = try h.f.allocate("NSObject");
        errdefer cls.dispose();

        try h.f.addProtocol(cls, "SCStreamOutput");
        try h.f.addIvar(cls, "context", *Context);
        try h.f.addMethod(cls, "stream:didOutputSampleBuffer:ofType:", receive);

        cls.register();
        return cls;
    }

    pub fn new(ctx: *Context) *Self {
        const self = h.cls.new();
        self.setContext(ctx);
        return self;
    }

    fn receive(self: *Self, _: *ffi.Sel, stream: *sck.SCStream, sample_buffer: macos.CMSampleBufferRef, output_type: sck.SCStreamOutputType) callconv(.c) void {
        const ctx = self.context();
        ctx.calls += 1;
        ctx.stream = stream;
        ctx.sample_buffer = sample_buffer;
        ctx.output_type = output_type;
    }
};

test "SCKStreamOutputTest: routes callback arguments to each instance context" {
    const cls = try SCKStreamOutputTest.registerClass();
    defer cls.dispose();

    var first_context: Context = .{};
    var second_context: Context = .{};
    const first = SCKStreamOutputTest.new(&first_context);
    defer first.release();
    const second = SCKStreamOutputTest.new(&second_context);
    defer second.release();

    // Opaque argument tokens: the callback only stores them and never dereferences them.
    const stream: *sck.SCStream = @ptrFromInt(0x1000);
    const sample_buffer: macos.CMSampleBufferRef = @ptrFromInt(0x2000);
    const h = obzc.h(SCKStreamOutputTest);
    h.call(first, void, "stream:didOutputSampleBuffer:ofType:", .{ stream, sample_buffer, sck.SCStreamOutputType.screen });
    h.call(second, void, "stream:didOutputSampleBuffer:ofType:", .{ stream, sample_buffer, sck.SCStreamOutputType.audio });

    try std.testing.expectEqual(1, first_context.calls);
    try std.testing.expectEqual(1, second_context.calls);
    for ([_]*Context{ &first_context, &second_context }) |context| {
        try std.testing.expectEqual(stream, context.stream.?);
        try std.testing.expectEqual(sample_buffer, context.sample_buffer);
    }
    try std.testing.expectEqual(sck.SCStreamOutputType.screen, first_context.output_type.?);
    try std.testing.expectEqual(sck.SCStreamOutputType.audio, second_context.output_type.?);
}
