const obzc = @import("obzc");
const case = @import("case");

const Auto = struct { value: u8 };
const Plain = union { value: u8 };
const Packed = packed union { value: u32 };
const Lowered = extern struct { byte: u8, value: u32 align(1) };
const Raised = extern struct { value: u32 align(8) };
const AlignedUnion = extern union { value: u32 align(8) };
const Nested = extern struct { value: Lowered };

const Cases = struct {
    const integer = u7;
    const zero_integer = u0;
    const float = f16;
    const vector = @Vector(2, f32);
    const auto_struct = Auto;
    const auto_struct_pointer = *Auto;
    const plain_union = Plain;
    const packed_union = Packed;
    const union_pointer = *Plain;
    const slice = []const u8;
    const optional_value = ?u32;
    const optional_slice = ?[]const u8;
    const optional_c_pointer = ?[*c]u8;
    const optional_allowzero = ?*allowzero i32;
    const nested_optional = ??*i32;
    const array_element = [2]?u32;
    const struct_alignment_lowered = Lowered;
    const struct_alignment_raised = Raised;
    const union_alignment = AlignedUnion;
    const nested_alignment = Nested;
};

comptime {
    _ = obzc.Block(void, fn (@field(Cases, case.name)) void);
}
