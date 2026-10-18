const std = @import("std");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const vision = @import("obzc-vision");
const VNRequest = vision.VNRequest;
const VNRecognizeTextRequest = vision.VNRecognizeTextRequest;
const VNImageRequestHandler = vision.VNImageRequestHandler;

test "VNImageRequestHandler: perform text recognition on a pixel buffer" {
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
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const data = ns.NSData.init(@embedFile("fixtures/text.png"));
    defer data.release();
    const options = ns.NSDictionary(ns.NSString, obzc.rt.Object).new();
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
