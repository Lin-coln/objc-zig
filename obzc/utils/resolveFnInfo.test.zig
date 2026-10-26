const resolveFnInfo = @import("resolveFnInfo.zig").resolveFnInfo;

pub const CompileTestCases = .{
    .{ .name = "utils.resolveFnInfo rejects a non-function shape", .expected_error = "Shape must be a function type" },
    .{ .name = "utils.resolveFnInfo rejects generic shapes by default", .expected_error = "Shape cannot have generic parameters" },
    .{ .name = "utils.resolveFnInfo rejects variadic shapes by default", .expected_error = "Shape cannot have C variadic parameters" },
    .{ .name = "utils.resolveFnInfo requires explicit parameter types", .expected_error = "Shape parameters must have explicit types" },
};

test "utils.resolveFnInfo rejects a non-function shape" {
    _ = resolveFnInfo(u32, .{});
}

test "utils.resolveFnInfo rejects generic shapes by default" {
    _ = resolveFnInfo(fn (anytype) void, .{});
}

test "utils.resolveFnInfo rejects variadic shapes by default" {
    _ = resolveFnInfo(fn (i32, ...) callconv(.c) void, .{});
}

test "utils.resolveFnInfo requires explicit parameter types" {
    _ = resolveFnInfo(fn (anytype) void, .{ .generic = true });
}
