const encodeType = @import("encode.zig").encodeType;

pub const CompileTestCases = .{
    .{
        .name = "encodeType: rejects u7",
        .expected_error = "cannot encode u7:",
    },
    .{
        .name = "encodeType: rejects u0",
        .expected_error = "cannot encode u0:",
    },
    .{
        .name = "encodeType: rejects f16",
        .expected_error = "cannot encode f16:",
    },
    .{
        .name = "encodeType: rejects bare functions",
        .expected_error = "cannot encode fn () void:",
    },
    .{
        .name = "encodeType: rejects opaque values",
        .expected_error = "cannot encode anyopaque:",
    },
    .{
        .name = "encodeType: rejects vectors",
        .expected_error = "cannot encode @Vector(2, f32):",
    },
    .{
        .name = "encodeType: rejects slices",
        .expected_error = "cannot encode []const u8:",
    },
    .{
        .name = "encodeType: rejects optional values",
        .expected_error = "cannot encode ?u32:",
    },
    .{
        .name = "encodeType: rejects optional slices",
        .expected_error = "cannot encode ?[]const u8:",
    },
    .{
        .name = "encodeType: rejects optional C pointers",
        .expected_error = "cannot encode ?[*c]u8:",
    },
    .{
        .name = "encodeType: rejects optional allowzero pointers",
        .expected_error = "cannot encode ?*allowzero i32:",
    },
    .{
        .name = "encodeType: rejects nested optionals",
        .expected_error = "cannot encode ??*i32:",
    },
    .{
        .name = "encodeType: rejects unsupported array elements",
        .expected_error = "cannot encode ?u32:",
    },
};

test "encodeType: rejects u7" {
    _ = comptime encodeType(u7);
}

test "encodeType: rejects u0" {
    _ = comptime encodeType(u0);
}

test "encodeType: rejects f16" {
    _ = comptime encodeType(f16);
}

test "encodeType: rejects bare functions" {
    _ = comptime encodeType(fn () void);
}

test "encodeType: rejects opaque values" {
    _ = comptime encodeType(anyopaque);
}

test "encodeType: rejects vectors" {
    _ = comptime encodeType(@Vector(2, f32));
}

test "encodeType: rejects slices" {
    _ = comptime encodeType([]const u8);
}

test "encodeType: rejects optional values" {
    _ = comptime encodeType(?u32);
}

test "encodeType: rejects optional slices" {
    _ = comptime encodeType(?[]const u8);
}

test "encodeType: rejects optional C pointers" {
    _ = comptime encodeType(?[*c]u8);
}

test "encodeType: rejects optional allowzero pointers" {
    _ = comptime encodeType(?*allowzero i32);
}

test "encodeType: rejects nested optionals" {
    _ = comptime encodeType(??*i32);
}

test "encodeType: rejects unsupported array elements" {
    _ = comptime encodeType([2]?u32);
}
