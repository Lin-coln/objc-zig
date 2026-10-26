const encode = @import("encode.zig").encode;

const Auto = struct { value: u8 };
const Plain = union { value: u8 };
const Packed = packed union { value: u32 };
const Lowered = extern struct { byte: u8, value: u32 align(1) };
const Raised = extern struct { value: u32 align(8) };
const AlignedUnion = extern union { value: u32 align(8) };
const Nested = extern struct { value: Lowered };

pub const CompileTestCases = .{
    .{
        .name = "block.encode: rejects u7",
        .expected_error = "cannot encode u7:",
    },
    .{
        .name = "block.encode: rejects u0",
        .expected_error = "cannot encode u0:",
    },
    .{
        .name = "block.encode: rejects f16",
        .expected_error = "cannot encode f16:",
    },
    .{
        .name = "block.encode: rejects bare functions",
        .expected_error = "cannot encode fn () void:",
    },
    .{
        .name = "block.encode: rejects opaque values",
        .expected_error = "cannot encode anyopaque:",
    },
    .{
        .name = "block.encode: rejects vectors",
        .expected_error = "cannot encode @Vector(2, f32):",
    },
    .{
        .name = "block.encode: rejects auto-layout structs",
        .expected_error = "cannot encode struct Auto:",
    },
    .{
        .name = "block.encode: rejects pointers to auto-layout structs",
        .expected_error = "cannot encode struct Auto:",
    },
    .{
        .name = "block.encode: rejects non-extern unions",
        .expected_error = "cannot encode union Plain:",
    },
    .{
        .name = "block.encode: rejects packed unions",
        .expected_error = "cannot encode union Packed:",
    },
    .{
        .name = "block.encode: rejects pointers to non-extern unions",
        .expected_error = "cannot encode union Plain:",
    },
    .{
        .name = "block.encode: rejects slices",
        .expected_error = "cannot encode slice of u8:",
    },
    .{
        .name = "block.encode: rejects optional values",
        .expected_error = "cannot encode ?u32:",
    },
    .{
        .name = "block.encode: rejects optional slices",
        .expected_error = "cannot encode ?[]const u8:",
    },
    .{
        .name = "block.encode: rejects optional C pointers",
        .expected_error = "cannot encode ?[*c]u8:",
    },
    .{
        .name = "block.encode: rejects optional allowzero pointers",
        .expected_error = "cannot encode ?*allowzero i32:",
    },
    .{
        .name = "block.encode: rejects nested optionals",
        .expected_error = "cannot encode ??*i32:",
    },
    .{
        .name = "block.encode: rejects unsupported array elements",
        .expected_error = "cannot encode ?u32:",
    },
    .{
        .name = "block.encode: rejects lowered struct field alignment",
        .expected_error = "cannot encode struct Lowered:",
    },
    .{
        .name = "block.encode: rejects raised struct field alignment",
        .expected_error = "cannot encode struct Raised:",
    },
    .{
        .name = "block.encode: rejects custom union field alignment",
        .expected_error = "cannot encode union AlignedUnion:",
    },
    .{
        .name = "block.encode: rejects custom field alignment in nested structs",
        .expected_error = "cannot encode struct Lowered:",
    },
};

test "block.encode: rejects u7" {
    _ = comptime encode(u7);
}

test "block.encode: rejects u0" {
    _ = comptime encode(u0);
}

test "block.encode: rejects f16" {
    _ = comptime encode(f16);
}

test "block.encode: rejects bare functions" {
    _ = comptime encode(fn () void);
}

test "block.encode: rejects opaque values" {
    _ = comptime encode(anyopaque);
}

test "block.encode: rejects vectors" {
    _ = comptime encode(@Vector(2, f32));
}

test "block.encode: rejects auto-layout structs" {
    _ = comptime encode(Auto);
}

test "block.encode: rejects pointers to auto-layout structs" {
    _ = comptime encode(*Auto);
}

test "block.encode: rejects non-extern unions" {
    _ = comptime encode(Plain);
}

test "block.encode: rejects packed unions" {
    _ = comptime encode(Packed);
}

test "block.encode: rejects pointers to non-extern unions" {
    _ = comptime encode(*Plain);
}

test "block.encode: rejects slices" {
    _ = comptime encode([]const u8);
}

test "block.encode: rejects optional values" {
    _ = comptime encode(?u32);
}

test "block.encode: rejects optional slices" {
    _ = comptime encode(?[]const u8);
}

test "block.encode: rejects optional C pointers" {
    _ = comptime encode(?[*c]u8);
}

test "block.encode: rejects optional allowzero pointers" {
    _ = comptime encode(?*allowzero i32);
}

test "block.encode: rejects nested optionals" {
    _ = comptime encode(??*i32);
}

test "block.encode: rejects unsupported array elements" {
    _ = comptime encode([2]?u32);
}

test "block.encode: rejects lowered struct field alignment" {
    _ = comptime encode(Lowered);
}

test "block.encode: rejects raised struct field alignment" {
    _ = comptime encode(Raised);
}

test "block.encode: rejects custom union field alignment" {
    _ = comptime encode(AlignedUnion);
}

test "block.encode: rejects custom field alignment in nested structs" {
    _ = comptime encode(Nested);
}
