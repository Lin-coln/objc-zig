const resolveReceiverType = @import("resolveReceiverType.zig").resolveReceiverType;

pub const CompileTestCases = .{
    .{ .name = "utils.resolveReceiverType rejects a non-function call", .expected_error = "call should be a fn" },
};

test "utils.resolveReceiverType rejects a non-function call" {
    _ = resolveReceiverType(u8, 42);
}
