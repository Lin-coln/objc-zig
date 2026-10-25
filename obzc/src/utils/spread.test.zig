const spread = @import("spread.zig");

const CArgs = extern struct { value: c_int };
extern fn variadic(CArgs, ...) void;

pub const CompileTestCases = .{
    .{ .name = "toSpreadedFn: rejects more than fifteen parameters", .expected_error = "Unsupported argument count" },
    .{ .name = "toSpreadedFn: rejects C varargs handler", .expected_error = "Variadic functions are not supported" },
};

test "toSpreadedFn: rejects more than fifteen parameters" {
    const Args = @Tuple(&@as([16]type, @splat(i32)));
    const Handler = struct {
        fn call(_: Args) void {}
    };
    _ = spread.toSpreadedFn(Handler.call, .{});
}

test "toSpreadedFn: rejects C varargs handler" {
    _ = spread.toSpreadedFn(variadic, .{});
}
