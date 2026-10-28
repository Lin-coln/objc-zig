const impl = @import("struct.zig");

const Auto = struct { value: u8 };
const Plain = union { value: u8 };
const Packed = packed union { value: u32 };
const Lowered = extern struct { byte: u8, value: u32 align(1) };
const Raised = extern struct { value: u32 align(8) };
const AlignedUnion = extern union { value: u32 align(8) };

const Stub = struct {
    fn encode(comptime _: type) []const u8 {
        return "X";
    }
};

pub const CompileTestCases = .{
    .{
        .name = "fromStruct: rejects auto-layout structs",
        .expected_error = "cannot encode struct " ++ @typeName(Auto) ++ ":",
    },
    .{
        .name = "fromUnion: rejects non-extern unions",
        .expected_error = "cannot encode union " ++ @typeName(Plain) ++ ":",
    },
    .{
        .name = "fromUnion: rejects packed unions",
        .expected_error = "cannot encode union " ++ @typeName(Packed) ++ ":",
    },
    .{
        .name = "fromStruct: rejects lowered field alignment",
        .expected_error = "cannot encode struct " ++ @typeName(Lowered) ++ ":",
    },
    .{
        .name = "fromStruct: rejects raised field alignment",
        .expected_error = "cannot encode struct " ++ @typeName(Raised) ++ ":",
    },
    .{
        .name = "fromUnion: rejects custom field alignment",
        .expected_error = "cannot encode union " ++ @typeName(AlignedUnion) ++ ":",
    },
};

test "fromStruct: rejects auto-layout structs" {
    _ = comptime impl.fromStruct(Stub.encode, Auto, @typeInfo(Auto).@"struct", .val);
}

test "fromUnion: rejects non-extern unions" {
    _ = comptime impl.fromUnion(Stub.encode, Plain, @typeInfo(Plain).@"union", .val);
}

test "fromUnion: rejects packed unions" {
    _ = comptime impl.fromUnion(Stub.encode, Packed, @typeInfo(Packed).@"union", .val);
}

test "fromStruct: rejects lowered field alignment" {
    _ = comptime impl.fromStruct(Stub.encode, Lowered, @typeInfo(Lowered).@"struct", .val);
}

test "fromStruct: rejects raised field alignment" {
    _ = comptime impl.fromStruct(Stub.encode, Raised, @typeInfo(Raised).@"struct", .val);
}

test "fromUnion: rejects custom field alignment" {
    _ = comptime impl.fromUnion(Stub.encode, AlignedUnion, @typeInfo(AlignedUnion).@"union", .val);
}
