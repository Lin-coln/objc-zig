const make = @import("makeWithCallback.zig").makeWithCallback;
const Object = @import("../../ffi/root.zig").Object;

const Helper = struct {
    pub fn call(comptime Return: type, _: [:0]const u8, _: anytype) Return {
        unreachable;
    }
};

pub const CompileTestCases = .{
    .{ .name = "helpers.withCallback: rejects missing block parameter", .expected_error = "Shape must end with a block function type" },
    .{ .name = "helpers.withCallback: rejects non-function block parameter", .expected_error = "Shape must be a function type" },
};

test "helpers.withCallback: rejects missing block parameter" {
    _ = make(null, Helper.call, "complete:", fn () void);
}

test "helpers.withCallback: rejects non-function block parameter" {
    _ = make(null, Helper.call, "complete:", fn (u32) void);
}
