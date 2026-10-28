const encode = @import("root.zig").encode;

const Auto = struct { value: u8 };
const Plain = union { value: u8 };
const Packed = packed union { value: u32 };
const Lowered = extern struct { byte: u8, value: u32 align(1) };
const Raised = extern struct { value: u32 align(8) };
const AlignedUnion = extern union { value: u32 align(8) };
const Nested = extern struct { value: Lowered };

pub const CompileTestCases = .{
    .{
        .name = "encode: rejects u7",
        .expected_error = "cannot encode u7:",
    },
    .{
        .name = "encode: rejects u0",
        .expected_error = "cannot encode u0:",
    },
    .{
        .name = "encode: rejects f16",
        .expected_error = "cannot encode f16:",
    },
    .{
        .name = "encode: rejects bare functions",
        .expected_error = "cannot encode fn () void:",
    },
    .{
        .name = "encode: rejects opaque values",
        .expected_error = "cannot encode anyopaque:",
    },
    .{
        .name = "encode: rejects vectors",
        .expected_error = "cannot encode @Vector(2, f32):",
    },
    .{
        .name = "encode: rejects auto-layout structs",
        .expected_error = "cannot encode struct " ++ @typeName(Auto) ++ ":",
    },
    .{
        .name = "encode: rejects pointers to auto-layout structs",
        .expected_error = "cannot encode struct " ++ @typeName(Auto) ++ ":",
    },
    .{
        .name = "encode: rejects non-extern unions",
        .expected_error = "cannot encode union " ++ @typeName(Plain) ++ ":",
    },
    .{
        .name = "encode: rejects packed unions",
        .expected_error = "cannot encode union " ++ @typeName(Packed) ++ ":",
    },
    .{
        .name = "encode: rejects pointers to non-extern unions",
        .expected_error = "cannot encode union " ++ @typeName(Plain) ++ ":",
    },
    .{
        .name = "encode: rejects slices",
        .expected_error = "cannot encode []const u8:",
    },
    .{
        .name = "encode: rejects optional values",
        .expected_error = "cannot encode ?u32:",
    },
    .{
        .name = "encode: rejects optional slices",
        .expected_error = "cannot encode ?[]const u8:",
    },
    .{
        .name = "encode: rejects optional C pointers",
        .expected_error = "cannot encode ?[*c]u8:",
    },
    .{
        .name = "encode: rejects optional allowzero pointers",
        .expected_error = "cannot encode ?*allowzero i32:",
    },
    .{
        .name = "encode: rejects nested optionals",
        .expected_error = "cannot encode ??*i32:",
    },
    .{
        .name = "encode: rejects unsupported array elements",
        .expected_error = "cannot encode ?u32:",
    },
    .{
        .name = "encode: rejects lowered struct field alignment",
        .expected_error = "cannot encode struct " ++ @typeName(Lowered) ++ ":",
    },
    .{
        .name = "encode: rejects raised struct field alignment",
        .expected_error = "cannot encode struct " ++ @typeName(Raised) ++ ":",
    },
    .{
        .name = "encode: rejects custom union field alignment",
        .expected_error = "cannot encode union " ++ @typeName(AlignedUnion) ++ ":",
    },
    .{
        .name = "encode: rejects custom field alignment in nested structs",
        .expected_error = "cannot encode struct " ++ @typeName(Lowered) ++ ":",
    },
};

test "encode: rejects u7" {
    _ = comptime encode(u7);
}

test "encode: rejects u0" {
    _ = comptime encode(u0);
}

test "encode: rejects f16" {
    _ = comptime encode(f16);
}

test "encode: rejects bare functions" {
    _ = comptime encode(fn () void);
}

test "encode: rejects opaque values" {
    _ = comptime encode(anyopaque);
}

test "encode: rejects vectors" {
    _ = comptime encode(@Vector(2, f32));
}

test "encode: rejects auto-layout structs" {
    _ = comptime encode(Auto);
}

test "encode: rejects pointers to auto-layout structs" {
    _ = comptime encode(*Auto);
}

test "encode: rejects non-extern unions" {
    _ = comptime encode(Plain);
}

test "encode: rejects packed unions" {
    _ = comptime encode(Packed);
}

test "encode: rejects pointers to non-extern unions" {
    _ = comptime encode(*Plain);
}

test "encode: rejects slices" {
    _ = comptime encode([]const u8);
}

test "encode: rejects optional values" {
    _ = comptime encode(?u32);
}

test "encode: rejects optional slices" {
    _ = comptime encode(?[]const u8);
}

test "encode: rejects optional C pointers" {
    _ = comptime encode(?[*c]u8);
}

test "encode: rejects optional allowzero pointers" {
    _ = comptime encode(?*allowzero i32);
}

test "encode: rejects nested optionals" {
    _ = comptime encode(??*i32);
}

test "encode: rejects unsupported array elements" {
    _ = comptime encode([2]?u32);
}

test "encode: rejects lowered struct field alignment" {
    _ = comptime encode(Lowered);
}

test "encode: rejects raised struct field alignment" {
    _ = comptime encode(Raised);
}

test "encode: rejects custom union field alignment" {
    _ = comptime encode(AlignedUnion);
}

test "encode: rejects custom field alignment in nested structs" {
    _ = comptime encode(Nested);
}
