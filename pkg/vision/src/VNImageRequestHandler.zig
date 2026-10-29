const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const Metadata = core.Metadata;
const Object = core.ffi.Object;
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const VNRequest = @import("VNRequest.zig").VNRequest;
const VNRecognizeTextRequest = @import("VNRecognizeTextRequest.zig").VNRecognizeTextRequest;

pub const VNImageRequestHandler = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);
    const Options = ns.NSDictionary(ns.NSString, Object);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Retains the image source, which must not be modified while the handler is alive.
    pub fn initWithData(data: *ns.NSData, options: *Options) *Self {
        return h.call(h.cls.alloc(), *Self, "initWithData:options:", .{ data, options });
    }

    /// Retains the image source, which must not be modified while the handler is alive.
    pub fn initWithCVPixelBuffer(pixel_buffer: macos.CVPixelBufferRef, options: *Options) *Self {
        return h.call(h.cls.alloc(), *Self, "initWithCVPixelBuffer:options:", .{ pixel_buffer, options });
    }

    /// Runs the requests synchronously, logging the SDK error on failure.
    pub fn performRequests(self: *Self, requests: *ns.NSArray(VNRequest)) !void {
        var err: ?*ns.NSError = null;
        const succeeded = h.call(self, bool, "performRequests:error:", .{ requests, &err });
        if (succeeded) return;

        if (err) |ns_error| ns_error.log() else if (!builtin.is_test)
            std.log.err("VNImageRequestHandler.performRequests failed without NSError", .{});
        return error.PerformRequestsFailed;
    }
};

test "VNImageRequestHandler: invalid image data fails without producing results" {
    const pool = core.AutoReleasePool.create();
    defer pool.release();
    const data = ns.NSData.init("not an image");
    defer data.release();
    const options = ns.NSDictionary(ns.NSString, Object).new();
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
