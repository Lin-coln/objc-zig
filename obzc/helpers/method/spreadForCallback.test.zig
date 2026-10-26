const spread = @import("spreadForCallback.zig");

fn Callback(comptime Context: type) type {
    return fn (Context) void;
}

extern fn variadic(c_int, ...) void;

pub const CompileTestCases = .{
    .{ .name = "helpers.toSpreadFn: rejects more than fifteen method arguments", .expected_error = "withCallback supports at most 15 method arguments" },
    .{ .name = "helpers.toSpreadFn: rejects C varargs handler", .expected_error = "Variadic functions are not supported" },
};

test "helpers.toSpreadFn: rejects more than fifteen method arguments" {
    const Args = @Tuple(&@as([16]type, @splat(i32)));
    const Handler = struct {
        fn call(ctx: anytype, args: Args, comptime cb: *const Callback(@TypeOf(ctx))) void {
            _ = args;
            _ = cb;
        }
    };
    _ = spread.toSpreadFn(Handler.call, .{}, Callback);
}

test "helpers.toSpreadFn: rejects C varargs handler" {
    _ = spread.toSpreadFn(variadic, .{}, Callback);
}
