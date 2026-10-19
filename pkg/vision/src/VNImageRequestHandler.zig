const std = @import("std");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const VNRequest = @import("VNRequest.zig").VNRequest;
const VNRecognizeTextRequest = @import("VNRecognizeTextRequest.zig").VNRecognizeTextRequest;

pub const VNImageRequestHandler = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);
    const Options = ns.NSDictionary(ns.NSString, obzc.rt.Object);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Retains the image source, which must not be modified while the handler is alive.
    pub fn initWithData(data: *ns.NSData, options: *Options) *Self {
        const initialize = h.method("initWithData:options:", fn (*ns.NSData, *Options) *Self);
        return initialize(h.cls.alloc(), data, options);
    }

    /// Retains the image source, which must not be modified while the handler is alive.
    pub fn initWithCVPixelBuffer(pixel_buffer: macos.CVPixelBufferRef, options: *Options) *Self {
        const initialize = h.method("initWithCVPixelBuffer:options:", fn (macos.CVPixelBufferRef, *Options) *Self);
        return initialize(h.cls.alloc(), pixel_buffer, options);
    }

    /// Runs the requests synchronously. An error is borrowed from the current autorelease pool.
    pub fn performRequests(self: *Self, requests: *ns.NSArray(VNRequest), err: ?*?*ns.NSError) bool {
        const perform = h.method("performRequests:error:", fn (*ns.NSArray(VNRequest), ?*?*ns.NSError) obzc.c.BOOL);
        return obzc.utils.cast.bool(perform(self, requests, err));
    }
};

test "VNImageRequestHandler: invalid image data fails without producing results" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const data = ns.NSData.init("not an image");
    defer data.release();
    const options = ns.NSDictionary(ns.NSString, obzc.rt.Object).new();
    defer options.release();
    const handler = VNImageRequestHandler.initWithData(data, options);
    defer handler.release();
    const request = VNRecognizeTextRequest.new();
    defer request.release();
    const requests = ns.NSArray(VNRequest).init(&.{@ptrCast(request)});
    defer requests.release();

    var err: ?*ns.NSError = null;
    try std.testing.expect(!handler.performRequests(requests, &err));
    try std.testing.expect(request.results() == null);
    if (err) |failure| {
        try std.testing.expect(failure.domain().utf8String().len > 0);
        try std.testing.expect(failure.localizedDescription().utf8String().len > 0);
    }
}

test "VNImageRequestHandler: a blank pixel buffer produces an empty result" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    var pixel_buffer: macos.CVPixelBufferRef = null;
    try std.testing.expectEqual(macos.kCVReturnSuccess, macos.CVPixelBufferCreate(
        null,
        256,
        128,
        macos.kCVPixelFormatType_32BGRA,
        null,
        &pixel_buffer,
    ));
    defer macos.CVBufferRelease(pixel_buffer);
    try std.testing.expectEqual(macos.kCVReturnSuccess, macos.CVPixelBufferLockBaseAddress(pixel_buffer, 0));
    const pixels: [*]u8 = @ptrCast(macos.CVPixelBufferGetBaseAddress(pixel_buffer).?);
    @memset(pixels[0..macos.CVPixelBufferGetDataSize(pixel_buffer)], 255);
    try std.testing.expectEqual(macos.kCVReturnSuccess, macos.CVPixelBufferUnlockBaseAddress(pixel_buffer, 0));
    const options = ns.NSDictionary(ns.NSString, obzc.rt.Object).new();
    defer options.release();
    const handler = VNImageRequestHandler.initWithCVPixelBuffer(pixel_buffer, options);
    defer handler.release();
    const request = VNRecognizeTextRequest.new();
    defer request.release();
    request.setRecognitionLevel(.fast);
    request.setUsesLanguageCorrection(false);
    const requests = ns.NSArray(VNRequest).init(&.{@ptrCast(request)});
    defer requests.release();

    var err: ?*ns.NSError = null;
    const succeeded = handler.performRequests(requests, &err);
    if (!succeeded) if (err) |failure| {
        const domain = failure.domain().utf8String();
        const description = failure.localizedDescription().utf8String();
        if (std.mem.eql(u8, domain, "com.apple.Vision") and failure.code() == 8 and
            std.mem.eql(u8, description, "Failed to create CVPixelBuffer"))
        {
            std.debug.print("Vision OCR skipped: this environment cannot create Vision's internal pixel buffer.\n", .{});
            return error.SkipZigTest;
        }
        std.debug.print("Vision error {s} ({d}): {s}\n", .{ domain, failure.code(), description });
    };
    try std.testing.expect(succeeded);
    try std.testing.expect(err == null);
    try std.testing.expectEqual(0, request.results().?.count());
}
