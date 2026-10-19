const std = @import("std");
const obzc = @import("obzc");
const mtl = @import("mtl-abi");
const MTLTexture = @import("MTLTexture.zig").MTLTexture;

pub const MTLRenderPassColorAttachmentDescriptor = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;

    pub const texture = h.prop(?*MTLTexture, "texture").getter;
    pub const setTexture = h.prop(?*MTLTexture, "texture").setter;
    pub const loadAction = h.prop(mtl.MTLLoadAction, "loadAction").getter;
    pub const setLoadAction = h.prop(mtl.MTLLoadAction, "loadAction").setter;
    pub const storeAction = h.prop(mtl.MTLStoreAction, "storeAction").getter;
    pub const setStoreAction = h.prop(mtl.MTLStoreAction, "storeAction").setter;
    pub const clearColor = h.prop(mtl.MTLClearColor, "clearColor").getter;
    pub const setClearColor = h.prop(mtl.MTLClearColor, "clearColor").setter;
};

test "MTLRenderPassColorAttachmentDescriptor: clear color struct and attachment actions" {
    const color = MTLRenderPassColorAttachmentDescriptor.new();
    defer color.release();
    try std.testing.expect(color.texture() == null);
    color.setTexture(null);
    color.setLoadAction(mtl.MTLLoadActionClear);
    color.setStoreAction(mtl.MTLStoreActionStore);
    color.setClearColor(.{ .red = 0.25, .green = 0.5, .blue = 0.75, .alpha = 1 });

    try std.testing.expectEqual(@as(mtl.MTLLoadAction, mtl.MTLLoadActionClear), color.loadAction());
    try std.testing.expectEqual(@as(mtl.MTLStoreAction, mtl.MTLStoreActionStore), color.storeAction());
    const clear = color.clearColor();
    try std.testing.expectEqual(0.25, clear.red);
    try std.testing.expectEqual(0.5, clear.green);
    try std.testing.expectEqual(0.75, clear.blue);
    try std.testing.expectEqual(1, clear.alpha);
}
