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
};

test "withCallback: rejects missing block parameter" {
    _ = m.withCallback("complete:", fn () void);
}

test "withCallback: rejects non-function block parameter" {
    _ = m.withCallback("complete:", fn (u32) void);
}
