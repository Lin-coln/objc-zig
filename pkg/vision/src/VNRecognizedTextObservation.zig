const std = @import("std");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const VNRecognizedText = @import("VNRecognizedText.zig").VNRecognizedText;

pub const VNRecognizedTextObservation = opaque {
    const h = obzc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;

    pub const confidence = h.prop(f32, "confidence").getter;
    pub const boundingBox = h.prop(macos.CGRect, "boundingBox").getter;

    /// Returns a borrowed array with at most the requested number of candidates.
    pub const topCandidates = h.method("topCandidates:", fn (usize) *ns.NSArray(VNRecognizedText));
};

test "VNRecognizedTextObservation: read a bounding box and confidence" {
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const create = obzc.helpers.Class(VNRecognizedTextObservation).method(
        "observationWithBoundingBox:",
        fn (macos.CGRect) *VNRecognizedTextObservation,
    );
    const bounds: macos.CGRect = .{
        .origin = .{ .x = 0.125, .y = 0.25 },
        .size = .{ .width = 0.5, .height = 0.5 },
    };
    const observation = create(bounds);

    const actual = observation.boundingBox();
    try std.testing.expectEqual(bounds.origin.x, actual.origin.x);
    try std.testing.expectEqual(bounds.origin.y, actual.origin.y);
    try std.testing.expectEqual(bounds.size.width, actual.size.width);
    try std.testing.expectEqual(bounds.size.height, actual.size.height);
    try std.testing.expectEqual(@as(f32, 1), observation.confidence());
}
