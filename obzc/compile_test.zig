pub const sources = .{
    @import("utils/spread.test.zig"),
    @import("utils/resolveFnInfo.test.zig"),
    @import("utils/resolveReceiverType.test.zig"),
    @import("src/Block/encode.test.zig"),
    @import("src/Block/Self.test.zig"),
    @import("block/encode.test.zig"),
    @import("helpers/block.test.zig"),
    @import("helpers/method/utils.test.zig"),
    @import("helpers/method/makeWithCallback.test.zig"),
    @import("helpers/method/makeWithSync.test.zig"),
    @import("helpers/method/spreadForCallback.test.zig"),
};

test {
    inline for (sources) |source| _ = source;
}
