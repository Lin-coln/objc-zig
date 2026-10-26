pub const sources = .{
    @import("utils/spread.test.zig"),
    @import("utils/resolveFnInfo.test.zig"),
    @import("utils/resolveReceiverType.test.zig"),
    @import("block/encode.test.zig"),
    @import("helpers2/method/initBlockWithContext.test.zig"),
    @import("helpers2/method/makeWithCallback.test.zig"),
    @import("helpers2/method/makeWithSync.test.zig"),
    @import("helpers2/method/spreadForCallback.test.zig"),
};

test {
    inline for (sources) |source| _ = source;
}
