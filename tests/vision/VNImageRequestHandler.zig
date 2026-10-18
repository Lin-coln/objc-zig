const std = @import("std");
const objc = @import("objc");
const ns = @import("objc/ns");
const macos = @import("macos");
const VNRequest = @import("VNRequest.zig").VNRequest;
const VNRecognizeTextRequest = @import("VNRecognizeTextRequest.zig").VNRecognizeTextRequest;

pub const VNImageRequestHandler = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);
    const Options = ns.NSDictionary(ns.NSString, objc.rt.Object);

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
        const perform = h.method("performRequests:error:", fn (*ns.NSArray(VNRequest), ?*?*ns.NSError) objc.c.BOOL);
        return objc.utils.cast.bool(perform(self, requests, err));
    }
};

test "VNImageRequestHandler: invalid image data fails without producing results" {
    const pool = objc.AutoReleasePool.create();
    defer pool.release();
    const data = ns.NSData.init("not an image");
    defer data.release();
    const options = ns.NSDictionary(ns.NSString, objc.rt.Object).new();
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

test "VNImageRequestHandler: perform text recognition on a pixel buffer" {
    const pool = objc.AutoReleasePool.create();
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
    const options = ns.NSDictionary(ns.NSString, objc.rt.Object).new();
    defer options.release();
    const handler = VNImageRequestHandler.initWithCVPixelBuffer(pixel_buffer, options);
    defer handler.release();
    const request = VNRecognizeTextRequest.new();
    defer request.release();
    request.setRecognitionLevel(.fast);
    request.setUsesLanguageCorrection(false);
    const language = ns.NSString.init("en-US").?;
    defer language.release();
    const languages = ns.NSArray(ns.NSString).init(&.{language});
    defer languages.release();
    request.setRecognitionLanguages(languages);
    const requests = ns.NSArray(VNRequest).init(&.{@ptrCast(request)});
    defer requests.release();

    try expectPerformed(handler, requests);
    const results = request.results().?;
    for (0..results.count()) |index| {
        const observation = results.objectAtIndex(index);
        try std.testing.expect(observation.confidence() >= 0 and observation.confidence() <= 1);
        const bounds = observation.boundingBox();
        try std.testing.expect(bounds.size.width >= 0 and bounds.size.height >= 0);
        const candidates = observation.topCandidates(1);
        try std.testing.expect(candidates.count() <= 1);
        for (0..candidates.count()) |candidate_index| {
            const candidate = candidates.objectAtIndex(candidate_index);
            try std.testing.expect(candidate.confidence() >= 0 and candidate.confidence() <= 1);
            try std.testing.expect(candidate.string().utf8String().len > 0);
        }
    }
}

test "VNImageRequestHandler: recognize text candidates from encoded image data" {
    const pool = objc.AutoReleasePool.create();
    defer pool.release();
    const data = ns.NSData.init(@embedFile("fixtures/text.png"));
    defer data.release();
    const options = ns.NSDictionary(ns.NSString, objc.rt.Object).new();
    defer options.release();
    const handler = VNImageRequestHandler.initWithData(data, options);
    defer handler.release();
    const request = VNRecognizeTextRequest.new();
    defer request.release();
    request.setRecognitionLevel(.fast);
    request.setUsesLanguageCorrection(false);
    const language = ns.NSString.init("en-US").?;
    defer language.release();
    const languages = ns.NSArray(ns.NSString).init(&.{language});
    defer languages.release();
    request.setRecognitionLanguages(languages);
    const requests = ns.NSArray(VNRequest).init(&.{@ptrCast(request)});
    defer requests.release();

    try expectPerformed(handler, requests);
    const results = request.results().?;
    try std.testing.expect(results.count() > 0);
    for (0..results.count()) |index| {
        const observation = results.objectAtIndex(index);
        try std.testing.expect(observation.confidence() >= 0 and observation.confidence() <= 1);
        const candidates = observation.topCandidates(1);
        try std.testing.expectEqual(1, candidates.count());
        const candidate = candidates.objectAtIndex(0);
        try std.testing.expect(candidate.confidence() >= 0 and candidate.confidence() <= 1);
        try std.testing.expect(candidate.string().utf8String().len > 0);
    }
}

fn expectPerformed(handler: *VNImageRequestHandler, requests: *ns.NSArray(VNRequest)) !void {
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
}
