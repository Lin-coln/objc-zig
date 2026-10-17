const std = @import("std");
const objc = @import("objc");

pub const SCStreamConfiguration = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const new = h.cls.new;
    pub const release = h.release;

    pub const width = h.prop(usize, "width").getter;
    pub const setWidth = h.prop(usize, "width").setter;
    pub const height = h.prop(usize, "height").getter;
    pub const setHeight = h.prop(usize, "height").setter;
    pub const queueDepth = h.prop(isize, "queueDepth").getter;
    pub const setQueueDepth = h.prop(isize, "queueDepth").setter;
    pub const showsCursor = h.prop(bool, "showsCursor").getter;
    pub const setShowsCursor = h.prop(bool, "showsCursor").setter;
    pub const capturesAudio = h.prop(bool, "capturesAudio").getter;
    pub const setCapturesAudio = h.prop(bool, "capturesAudio").setter;
};

test "SCStreamConfiguration: configure video and audio properties" {
    const configuration = SCStreamConfiguration.new();
    defer configuration.release();

    configuration.setWidth(1280);
    configuration.setHeight(720);
    configuration.setQueueDepth(4);
    configuration.setShowsCursor(false);
    configuration.setCapturesAudio(true);

    try std.testing.expectEqual(1280, configuration.width());
    try std.testing.expectEqual(720, configuration.height());
    try std.testing.expectEqual(4, configuration.queueDepth());
    try std.testing.expectEqual(false, configuration.showsCursor());
    try std.testing.expectEqual(true, configuration.capturesAudio());
}
