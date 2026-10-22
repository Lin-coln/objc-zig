const std = @import("std");
const builtin = @import("builtin");
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
        const initialize = h.m.of("initWithData:options:", fn (*ns.NSData, *Options) *Self);
        return initialize(h.cls.alloc(), data, options);
    }

    /// Retains the image source, which must not be modified while the handler is alive.
    pub fn initWithCVPixelBuffer(pixel_buffer: macos.CVPixelBufferRef, options: *Options) *Self {
        const initialize = h.m.of("initWithCVPixelBuffer:options:", fn (macos.CVPixelBufferRef, *Options) *Self);
        return initialize(h.cls.alloc(), pixel_buffer, options);
    }

    /// Runs the requests synchronously, logging the SDK error on failure.
    pub fn performRequests(self: *Self, requests: *ns.NSArray(VNRequest)) !void {
        var err: ?*ns.NSError = null;
        const succeeded = h.msgSend(self, obzc.c.BOOL, "performRequests:error:", .{ requests, &err });
        if (obzc.utils.cast.bool(succeeded)) return;

        if (err) |ns_error| ns_error.log() else if (!builtin.is_test)
            std.log.err("VNImageRequestHandler.performRequests failed without NSError", .{});
        return error.PerformRequestsFailed;
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

    try std.testing.expectError(error.PerformRequestsFailed, handler.performRequests(requests));
    try std.testing.expect(request.results() == null);
}
