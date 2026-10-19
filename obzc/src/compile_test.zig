pub const sources = .{
    @import("Block/encode.test.zig"),
};

test {
    inline for (sources) |source| _ = source;
}
