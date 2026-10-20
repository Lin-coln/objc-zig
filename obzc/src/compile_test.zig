pub const sources = .{
    @import("Block/encode.test.zig"),
    @import("utils/spreadArgs.test.zig"),
};

test {
    inline for (sources) |source| _ = source;
}
