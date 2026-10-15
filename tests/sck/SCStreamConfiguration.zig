const std = @import("std");
const objc = @import("objc");

pub const SCStreamConfiguration = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub fn new() *Self {
        return @ptrCast(objc.getClass("SCStreamConfiguration").?.new());
    }

    pub const release = h.release;

    pub const getWidth = h.prop(usize, "width").getter;
    pub const setWidth = h.prop(usize, "width").setter;
    pub const getHeight = h.prop(usize, "height").getter;
    pub const setHeight = h.prop(usize, "height").setter;
    pub const getQueueDepth = h.prop(isize, "queueDepth").getter;
    pub const setQueueDepth = h.prop(isize, "queueDepth").setter;
    pub const getShowsCursor = h.prop(objc.c.BOOL, "showsCursor").getter;
    pub const setShowsCursor = h.prop(objc.c.BOOL, "showsCursor").setter;
    pub const getCapturesAudio = h.prop(objc.c.BOOL, "capturesAudio").getter;
    pub const setCapturesAudio = h.prop(objc.c.BOOL, "capturesAudio").setter;
};

test "SCStreamConfiguration: configure video and audio properties" {
    const configuration = SCStreamConfiguration.new();
    defer configuration.release();

    configuration.setWidth(1280);
    configuration.setHeight(720);
    configuration.setQueueDepth(4);
    configuration.setShowsCursor(objc.c.NO);
    configuration.setCapturesAudio(objc.c.YES);

    try std.testing.expectEqual(1280, configuration.getWidth());
    try std.testing.expectEqual(720, configuration.getHeight());
    try std.testing.expectEqual(4, configuration.getQueueDepth());
    try std.testing.expectEqual(objc.c.NO, configuration.getShowsCursor());
    try std.testing.expectEqual(objc.c.YES, configuration.getCapturesAudio());
}
