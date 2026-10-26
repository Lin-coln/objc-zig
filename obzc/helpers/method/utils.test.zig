const utils = @import("utils.zig");

pub const CompileTestCases = .{
    .{ .name = "resolveReceiverType: rejects non-function call", .expected_error = "call should be a fn" },
    .{ .name = "resolveFnInfo: rejects non-function shape", .expected_error = "Shape must be a function type" },
    .{ .name = "resolveFnInfo: rejects generic shape", .expected_error = "Shape cannot have generic parameters" },
    .{ .name = "resolveFnInfo: rejects C varargs", .expected_error = "Shape cannot have C variadic parameters" },
    .{ .name = "resolveFnInfo: requires explicit parameter types", .expected_error = "Shape parameters must have explicit types" },
};

test "resolveReceiverType: rejects non-function call" {
    _ = utils.resolveReceiverType(u8, 42);
}

test "resolveFnInfo: rejects non-function shape" {
    _ = utils.resolveFnInfo(u32, .{});
}

test "resolveFnInfo: rejects generic shape" {
    _ = utils.resolveFnInfo(fn (anytype) void, .{});
}

test "resolveFnInfo: rejects C varargs" {
    _ = utils.resolveFnInfo(fn (i32, ...) callconv(.c) void, .{});
}

test "resolveFnInfo: requires explicit parameter types" {
    _ = utils.resolveFnInfo(fn (anytype) void, .{ .generic = true });
}
