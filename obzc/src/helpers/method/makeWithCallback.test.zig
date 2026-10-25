const Method = @import("root.zig").Method;
const Object = @import("../../rt/Object.zig").Object;

const Helper = struct {
    pub fn call(comptime Return: type, _: [:0]const u8, _: anytype) Return {
        unreachable;
    }
};
const m = Method(Object, Helper);

pub const CompileTestCases = .{
    .{ .name = "withCallback: rejects missing block parameter", .expected_error = "Shape must end with a block function type" },
    .{ .name = "withCallback: rejects non-function block parameter", .expected_error = "Shape must be a function type" },
    // .{ .name = "withCallback: rejects method return values", .expected_error = "withCallback Shape must return void" },
    .{ .name = "withCallback: rejects generic block parameters", .expected_error = "Shape cannot have generic parameters" },
    .{ .name = "withCallback: rejects more than fifteen method arguments", .expected_error = "withCallback supports at most 15 method arguments" },
};

test "withCallback: rejects missing block parameter" {
    _ = m.withCallback("complete:", fn () void);
}

test "withCallback: rejects non-function block parameter" {
    _ = m.withCallback("complete:", fn (u32) void);
}

// test "withCallback: rejects method return values" {
//     _ = m.withCallback("complete:", fn (fn () void) bool);
// }

test "withCallback: rejects generic block parameters" {
    _ = m.withCallback("complete:", fn (fn (anytype) void) void);
}

test "withCallback: rejects more than fifteen method arguments" {
    comptime var params: [17]type = undefined;
    inline for (0..16) |i| params[i] = i32;
    params[16] = fn () void;
    const Shape = @Fn(&params, &@splat(.{}), void, .{});
    _ = m.withCallback("complete:", Shape);
}
