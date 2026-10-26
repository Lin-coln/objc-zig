const std = @import("std");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const VNRecognizedTextObservation = @import("VNRecognizedTextObservation.zig").VNRecognizedTextObservation;

pub const VNRequestTextRecognitionLevel = enum(isize) {
    accurate = 0,
    fast = 1,
};

pub const VNRecognizeTextRequest = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const recognitionLevel = h.prop("recognitionLevel", VNRequestTextRecognitionLevel).getter;
    pub const setRecognitionLevel = h.prop("recognitionLevel", VNRequestTextRecognitionLevel).setter;
    pub const recognitionLanguages = h.prop("recognitionLanguages", *ns.NSArray(ns.NSString)).getter;
    pub const setRecognitionLanguages = h.prop("recognitionLanguages", *ns.NSArray(ns.NSString)).setter;
    pub const usesLanguageCorrection = h.prop("usesLanguageCorrection", bool).getter;
    pub const setUsesLanguageCorrection = h.prop("usesLanguageCorrection", bool).setter;
    pub const minimumTextHeight = h.prop("minimumTextHeight", f32).getter;
    pub const setMinimumTextHeight = h.prop("minimumTextHeight", f32).setter;
    pub const regionOfInterest = h.prop("regionOfInterest", macos.CGRect).getter;
    pub const setRegionOfInterest = h.prop("regionOfInterest", macos.CGRect).setter;

    /// Results are borrowed and remain null until the request has produced results.
    pub const results = h.prop("results", ?*ns.NSArray(VNRecognizedTextObservation)).getter;
};

test "VNRecognizeTextRequest: configure recognition and region of interest" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const request = VNRecognizeTextRequest.new();
    defer request.release();

    request.setRecognitionLevel(.fast);
    request.setUsesLanguageCorrection(false);
    request.setMinimumTextHeight(0.125);
    const region: macos.CGRect = .{
        .origin = .{ .x = 0.125, .y = 0.25 },
        .size = .{ .width = 0.5, .height = 0.5 },
    };
    request.setRegionOfInterest(region);

    try std.testing.expectEqual(.fast, request.recognitionLevel());
    try std.testing.expectEqual(false, request.usesLanguageCorrection());
    try std.testing.expectEqual(@as(f32, 0.125), request.minimumTextHeight());
    const actual = request.regionOfInterest();
    try std.testing.expectEqual(region.origin.x, actual.origin.x);
    try std.testing.expectEqual(region.origin.y, actual.origin.y);
    try std.testing.expectEqual(region.size.width, actual.size.width);
    try std.testing.expectEqual(region.size.height, actual.size.height);
    try std.testing.expect(request.results() == null);

    const language = ns.NSString.init("en-US").?;
    defer language.release();
    const languages = ns.NSArray(ns.NSString).init(&.{language});
    defer languages.release();
    request.setRecognitionLanguages(languages);

    const actual_languages = request.recognitionLanguages();
    try std.testing.expectEqual(1, actual_languages.count());
    try std.testing.expectEqualStrings("en-US", actual_languages.objectAtIndex(0).utf8String());
}
