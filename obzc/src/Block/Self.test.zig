const generateFromFnType = @import("Self.zig").generateFromFnType;

pub const CompileTestCases = .{
    .{
        .name = "Block signature: rejects non-function types",
        .expected_error = "expected a function type, got u32",
    },
    .{
        .name = "Block signature: rejects generic parameters",
        .expected_error = "a block signature requires a non-generic function with fixed parameters",
    },
    .{
        .name = "Block signature: rejects C varargs",
        .expected_error = "a block signature requires a non-generic function with fixed parameters",
    },
};

test "Block signature: rejects non-function types" {
    _ = comptime generateFromFnType(u32);
}

test "Block signature: rejects generic parameters" {
    const generic = struct {
        fn invoke(_: anytype) void {}
    }.invoke;
    _ = comptime generateFromFnType(@TypeOf(generic));
}

test "Block signature: rejects C varargs" {
    _ = comptime generateFromFnType(fn (...) callconv(.c) void);
}
