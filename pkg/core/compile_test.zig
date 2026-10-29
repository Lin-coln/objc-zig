pub const sources = .{
    @import("encode/encode.test.zig"),
    @import("encode/struct.test.zig"),
    @import("utils/spread.test.zig"),
    @import("utils/resolveFnInfo.test.zig"),
    @import("utils/resolveReceiverType.test.zig"),
    @import("helpers/method/initBlockWithContext.test.zig"),
    @import("helpers/method/makeWithCallback.test.zig"),
    @import("helpers/method/makeWithSync.test.zig"),
    @import("helpers/method/spreadForCallback.test.zig"),
};

test {
    inline for (sources) |source| _ = source;
}
