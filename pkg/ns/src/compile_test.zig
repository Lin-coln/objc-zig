pub const sources = .{
    @import("NSNumber.test.zig"),
};

test {
    inline for (sources) |source| _ = source;
}
