const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const VNRecognizedText = @import("VNRecognizedText.zig").VNRecognizedText;

pub const VNRecognizedTextObservation = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const confidence = h.prop("confidence", f32).getter;
    pub const boundingBox = h.prop("boundingBox", macos.CGRect).getter;

    /// Returns a borrowed array with at most the requested number of candidates.
    pub const topCandidates = h.method("topCandidates:", fn (usize) *ns.NSArray(VNRecognizedText));
};

test "VNRecognizedTextObservation: read a bounding box and confidence" {
    const pool = core.AutoReleasePool.create();
    defer pool.release();
    const bounds: macos.CGRect = .{
        .origin = .{ .x = 0.125, .y = 0.25 },
        .size = .{ .width = 0.5, .height = 0.5 },
    };
    const observation = core.h(VNRecognizedTextObservation).cls.call(
        *VNRecognizedTextObservation,
        "observationWithBoundingBox:",
        .{bounds},
    );

    const actual = observation.boundingBox();
    try std.testing.expectEqual(bounds.origin.x, actual.origin.x);
    try std.testing.expectEqual(bounds.origin.y, actual.origin.y);
    try std.testing.expectEqual(bounds.size.width, actual.size.width);
    try std.testing.expectEqual(bounds.size.height, actual.size.height);
    try std.testing.expectEqual(@as(f32, 1), observation.confidence());
}
