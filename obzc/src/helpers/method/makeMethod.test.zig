const Method = @import("root.zig").Method;
const Object = @import("../../rt/Object.zig").Object;

const Helper = struct {
    pub fn call(comptime Return: type, _: [:0]const u8, _: anytype) Return {
        unreachable;
    }
};
const m = Method(Object, Helper);

pub const CompileTestCases = .{
    .{ .name = "of: rejects non-function shape", .expected_error = "Shape must be a function type" },
    .{ .name = "of: rejects generic shape", .expected_error = "Shape cannot have generic parameters" },
};

test "of: rejects non-function shape" {
    _ = m.of("value", u32);
}

test "of: rejects generic shape" {
    _ = m.of("value:", fn (anytype) void);
}
