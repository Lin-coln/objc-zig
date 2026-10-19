const std = @import("std");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const vision = @import("obzc-vision");
const VNRequest = vision.VNRequest;
const VNRecognizeTextRequest = vision.VNRecognizeTextRequest;
const VNImageRequestHandler = vision.VNImageRequestHandler;

test "text recognition: encoded image data produces readable candidates" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const handler = blk: {
        const data = ns.NSData.init(@embedFile("fixtures/text.png"));
        defer data.release();
        const options = ns.NSDictionary(ns.NSString, obzc.rt.Object).new();
        defer options.release();
        break :blk VNImageRequestHandler.initWithData(data, options);
    };
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

    // The handler must keep the image source alive after its caller releases it.
    try expectPerformed(handler, requests);
    const results = request.results().?;
    try std.testing.expect(results.count() > 0);
    var candidate_count: usize = 0;
    const tolerance = 0.000001;
    for (0..results.count()) |index| {
        const observation = results.objectAtIndex(index);
        try std.testing.expect(observation.confidence() >= 0 and observation.confidence() <= 1);
        const bounds = observation.boundingBox();
        try std.testing.expect(bounds.origin.x >= -tolerance and bounds.origin.x <= 1 + tolerance);
        try std.testing.expect(bounds.origin.y >= -tolerance and bounds.origin.y <= 1 + tolerance);
        try std.testing.expect(bounds.size.width > 0 and bounds.size.width <= 1 + tolerance);
        try std.testing.expect(bounds.size.height > 0 and bounds.size.height <= 1 + tolerance);
        const candidates = observation.topCandidates(1);
        try std.testing.expect(candidates.count() <= 1);
        for (0..candidates.count()) |candidate_index| {
            const candidate = candidates.objectAtIndex(candidate_index);
            try std.testing.expect(candidate.confidence() >= 0 and candidate.confidence() <= 1);
            try std.testing.expect(candidate.string().utf8String().len > 0);
            candidate_count += 1;
        }
    }
    try std.testing.expect(candidate_count > 0);
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
