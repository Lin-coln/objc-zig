pub const sources = .{
    @import("src/Block/encode.test.zig"),
    @import("src/Block/Self.test.zig"),
    @import("helpers/block.test.zig"),
    @import("helpers/method/utils.test.zig"),
    @import("helpers/method/makeWithCallback.test.zig"),
    @import("helpers/method/makeWithSync.test.zig"),
    @import("helpers/method/spreadForCallback.test.zig"),
    @import("src/utils/spread.test.zig"),
};

test {
    inline for (sources) |source| _ = source;
}
