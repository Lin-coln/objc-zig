const std = @import("std");
const rt = @import("../rt/root.zig");
const utils = @import("../../utils/root.zig");
const Type = std.lang.Type;

/// Returns the Objective-C encoding of a Zig type, e.g. `i32` -> `i`, `*i32` -> `^i`.
/// Unsupported types and layouts produce compile errors describing the reason.
pub fn encode(comptime T: type) []const u8 {
    return comptime encodeAnytype(T);
}

/// Matches runtime Object/Class/Sel pointers as `@`/`#`/`:` before general types.
/// Fixed encodings: void/bool/f32/f64/c_longdouble -> `v`/`B`/`f`/`d`/`D`;
/// sentinel and C u8 pointers -> `*`. Enums use their tag type; arrays use `[countElement]`.
/// An array's count includes its sentinel element, if present.
/// All recursive encoders return here to apply the same rules to nested types.
/// Unsupported types produce a diagnostic at the failing recursive step.
fn encodeAnytype(comptime T: type) []const u8 {
    var encoded: ?[]const u8 = switch (T) {
        *rt.Object, *const rt.Object, ?*rt.Object, ?*const rt.Object => "@",
        *rt.Class, *const rt.Class, ?*rt.Class, ?*const rt.Class => "#",
        *rt.Sel, *const rt.Sel, ?*rt.Sel, ?*const rt.Sel => ":",
        else => null,
    };
    if (encoded) |value| return value;

    encoded = switch (T) {
        void => "v",
        bool => "B",
        f32 => "f",
        f64 => "d",
        c_longdouble => "D",
        [*:0]u8, [*:0]const u8, [*c]u8, [*c]const u8 => "*",
        else => null,
    };
    if (encoded) |value| return value;

    return switch (@typeInfo(T)) {
        .int => |info| encodeInt(info),
        .@"enum" => |info| encodeAnytype(info.tag_type),
        .@"union" => |info| encodeUnion(info, resolveStructName(T), .value),
        .@"struct" => |info| encodeStruct(info, resolveStructName(T), .value),
        .optional => |info| encodeOptional(info),
        .pointer => |info| encodePointer(info),
        .array => |info| blk: {
            const element = encodeAnytype(info.child);
            const len = if (info.sentinel_ptr != null) info.len + 1 else info.len;
            break :blk std.fmt.comptimePrint("[{d}{s}]", .{ len, element });
        },
        .float => @compileError("cannot encode " ++ @typeName(T) ++ ":\nonly f32, f64 and c_longdouble floating-point encodings are supported"),
        .@"fn" => @compileError("cannot encode " ++ @typeName(T) ++ ":\na function type is not a C value; use a function pointer"),
        .@"opaque" => @compileError("cannot encode " ++ @typeName(T) ++ ":\nan opaque value has no known layout; use an opaque pointer"),
        else => @compileError("cannot encode " ++ @typeName(T) ++ ":\nZig type category " ++ @tagName(@typeInfo(T)) ++ " has no supported Objective-C type encoding"),
    };
}

/// Signed 8/16/32/64/128-bit integers -> `c`/`s`/`i`/`q`/`t`;
/// unsigned equivalents -> `C`/`S`/`I`/`Q`/`T`. Other widths produce a compile error.
/// Encoding follows bit width, independently of the target's `long`.
fn encodeInt(int: Type.Int) []const u8 {
    return switch (int.bits) {
        8 => if (int.signedness == .signed) "c" else "C",
        16 => if (int.signedness == .signed) "s" else "S",
        32 => if (int.signedness == .signed) "i" else "I",
        64 => if (int.signedness == .signed) "q" else "Q",
        128 => if (int.signedness == .signed) "t" else "T",
        else => @compileError(std.fmt.comptimePrint("cannot encode {s}{d}:\nObjective-C integer encodings support only 8, 16, 32, 64 and 128 bits", .{
            if (int.signedness == .signed) "i" else "u", int.bits,
        })),
    };
}

/// Extern union: .value -> `(Name=Fields)`, .reference -> `(Name)`.
/// Only .value encodes members; references stop before self-referential fields.
/// Non-extern unions, non-natural field alignment and unsupported value members produce compile errors.
fn encodeUnion(info: Type.Union, name: []const u8, mode: enum { value, reference }) []const u8 {
    if (info.layout != .@"extern") @compileError("cannot encode union " ++ name ++ ":\nonly extern unions have a supported Objective-C layout");
    if (mode == .reference) return "(" ++ name ++ ")";
    var fields: []const u8 = "";
    for (info.field_types, info.field_names, info.field_attrs) |F, field, attrs| {
        const alignment = attrs.@"align" orelse @alignOf(F);
        if (alignment != @alignOf(F)) @compileError(std.fmt.comptimePrint(
            "cannot encode union {s}:\nfield {s}: alignment is {d}, natural alignment is {d}; Objective-C type encoding cannot represent custom field alignment",
            .{ name, field, alignment, @alignOf(F) },
        ));
        fields = fields ++ encodeAnytype(F);
    }
    return "(" ++ name ++ "=" ++ fields ++ ")";
}

/// Extern struct: .value -> `{Name=Fields}`, .reference -> `{Name}` without traversing fields.
/// Packed structs use their backing integer encoding in both modes, e.g. packed(u32) -> `I`.
/// Auto-layout structs, non-natural extern field alignment and unsupported value fields produce compile errors.
fn encodeStruct(info: Type.Struct, name: []const u8, mode: enum { value, reference }) []const u8 {
    return switch (info.layout) {
        .auto => @compileError("cannot encode struct " ++ name ++ ":\nauto layout is not C-compatible; use an extern or packed struct"),
        .@"packed" => encodeAnytype(info.backing_integer.?),
        .@"extern" => blk: {
            if (mode == .reference) break :blk "{" ++ name ++ "}";
            var fields: []const u8 = "";
            for (info.field_types, info.field_names, info.field_attrs) |F, field, attrs| {
                const alignment = attrs.@"align" orelse @alignOf(F);
                if (alignment != @alignOf(F)) @compileError(std.fmt.comptimePrint(
                    "cannot encode struct {s}:\nfield {s}: alignment is {d}, natural alignment is {d}; Objective-C type encoding cannot represent custom field alignment",
                    .{ name, field, alignment, @alignOf(F) },
                ));
                fields = fields ++ encodeAnytype(F);
            }
            break :blk "{" ++ name ++ "=" ++ fields ++ "}";
        },
    };
}

/// Nullable one/many pointers reuse their child's encoding: `?*i32` -> `^i`.
/// Slices, C pointers and allowzero pointers cannot reuse a single pointer's representation.
/// Those cases and non-pointer optionals produce compile errors explaining the layout mismatch.
fn encodeOptional(info: Type.Optional) []const u8 {
    if (@typeInfo(info.child) != .pointer) @compileError("cannot encode ?" ++ @typeName(info.child) ++ ":\nonly nullable C-compatible pointers can reuse their payload encoding");
    const pointer = @typeInfo(info.child).pointer;
    if (pointer.size == .slice) @compileError("cannot encode ?" ++ @typeName(info.child) ++ ":\nan optional slice contains a pointer and length, not a nullable C pointer");
    if (pointer.size == .c) @compileError("cannot encode ?" ++ @typeName(info.child) ++ ":\nC pointers already allow address zero, so the optional needs extra presence state; use the C pointer directly");
    if (pointer.attrs.@"allowzero") @compileError("cannot encode ?" ++ @typeName(info.child) ++ ":\nallowzero makes address zero a valid payload, so the optional needs extra presence state");
    return encodeAnytype(info.child);
}

/// Prepends `^` to the pointee encoding; functions -> `^?`, opaque types -> `^v`.
/// Struct/union references omit fields (`^{Name}`/`^(Name)`); packed struct pointers use `^Integer`.
/// Slices contain a pointer and length, so they and unsupported pointees produce compile errors.
/// Fixed object and string pointer encodings are handled earlier by encodeAnytype.
fn encodePointer(info: Type.Pointer) []const u8 {
    if (info.size == .slice) @compileError("cannot encode slice of " ++ @typeName(info.child) ++ ":\na slice contains a pointer and length; pass a C-compatible pointer and length separately");
    const Child = info.child;

    return switch (@typeInfo(Child)) {
        .@"fn" => "^?",
        .@"opaque" => "^v",
        .@"struct" => |s| "^" ++ encodeStruct(s, resolveStructName(Child), .reference),
        .@"union" => |u| "^" ++ encodeUnion(u, resolveStructName(Child), .reference),
        else => "^" ++ encodeAnytype(Child),
    };
}

/// Removes translate-c's aggregate tag prefixes from the resolved type name.
fn resolveStructName(comptime T: type) []const u8 {
    const name = utils.resolveTypeName(@typeName(T));
    if (std.mem.startsWith(u8, name, "struct_")) return name["struct_".len..];
    if (std.mem.startsWith(u8, name, "union_")) return name["union_".len..];
    return name;
}

test "encode" {
    const Record = extern struct {
        callback: ?*const fn () callconv(.c) void,
        values: [2]u16,
        object: ?*const rt.Object,
    };
    const Sentinel = extern struct { data: [3:0]u8 };
    try std.testing.expectEqualStrings("{Record=^?[2S]@}", comptime encode(Record));
    try std.testing.expectEqualStrings("{Sentinel=[4C]}", comptime encode(Sentinel));
}

test "encodeAnytype" {
    const Kind = enum(u16) { value };
    const cases = .{
        .{ *rt.Object, "@" },   .{ *const rt.Object, "@" }, .{ ?*rt.Object, "@" },    .{ ?*const rt.Object, "@" },
        .{ *rt.Class, "#" },    .{ *const rt.Class, "#" },  .{ ?*rt.Class, "#" },     .{ ?*const rt.Class, "#" },
        .{ *rt.Sel, ":" },      .{ *const rt.Sel, ":" },    .{ ?*rt.Sel, ":" },       .{ ?*const rt.Sel, ":" },
        .{ void, "v" },         .{ bool, "B" },             .{ f32, "f" },            .{ f64, "d" },
        .{ c_longdouble, "D" }, .{ [*:0]u8, "*" },          .{ [*:0]const u8, "*" },  .{ [*c]u8, "*" },
        .{ [*c]const u8, "*" }, .{ Kind, "S" },             .{ [2][4]u8, "[2[4C]]" }, .{ [2]?*rt.Object, "[2@]" },
        .{ [3:0]u8, "[4C]" },   .{ [0:0]u8, "[1C]" },       .{ [2:7]u16, "[3S]" },    .{ [2][3:0]u8, "[2[4C]]" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime encodeAnytype(case[0]));
    }
}

test "encodeInt" {
    const cases = .{
        .{ i8, "c" },   .{ u8, "C" },   .{ i16, "s" }, .{ u16, "S" },
        .{ i32, "i" },  .{ u32, "I" },  .{ i64, "q" }, .{ u64, "Q" },
        .{ i128, "t" }, .{ u128, "T" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime encodeInt(@typeInfo(case[0]).int));
    }
}

test "encodeUnion" {
    const Value = extern union { integer: i32, bytes: [4]u8, object: ?*rt.Object };
    const Link = extern union { next: ?*@This(), value: i32 };
    const Auto = struct { value: u8 };
    const Unsupported = extern union { pointer: *Auto };
    const Natural = extern union { value: u32 align(4) };
    const Aligned = extern union { value: u32 align(8) };

    try std.testing.expectEqualStrings("(Value=i[4C]@)", comptime encodeUnion(@typeInfo(Value).@"union", "Value", .value));
    try std.testing.expectEqualStrings("(Value)", comptime encodeUnion(@typeInfo(Value).@"union", "Value", .reference));
    try std.testing.expectEqualStrings("(Link=^(Link)i)", comptime encodeUnion(@typeInfo(Link).@"union", "Link", .value));
    try std.testing.expectEqualStrings("(Unsupported)", comptime encodeUnion(@typeInfo(Unsupported).@"union", "Unsupported", .reference));
    try std.testing.expectEqualStrings("(Natural=I)", comptime encodeUnion(@typeInfo(Natural).@"union", "Natural", .value));
    try std.testing.expectEqualStrings("(Aligned)", comptime encodeUnion(@typeInfo(Aligned).@"union", "Aligned", .reference));
}

test "encodeStruct" {
    const Point = extern struct { x: f64, y: f64 };
    const Node = extern struct { next: ?*@This(), value: i32 };
    const Handles = extern struct { object: ?*rt.Object, class: *const rt.Class, selector: ?*rt.Sel };
    const Flags = packed struct(u32) { value: u32 };
    const Auto = struct { value: u8 };
    const Unsupported = extern struct { pointer: *Auto };
    const Natural = extern struct { value: u32 align(4) };
    const Aligned = extern struct { byte: u8, value: u32 align(1) };
    const cases = .{
        .{ Point, .value, "{Point=dd}" },      .{ Point, .reference, "{Point}" },
        .{ Node, .value, "{Node=^{Node}i}" },  .{ Node, .reference, "{Node}" },
        .{ Handles, .value, "{Handles=@#:}" }, .{ Flags, .value, "I" },
        .{ Flags, .reference, "I" },           .{ Unsupported, .reference, "{Unsupported}" },
        .{ Natural, .value, "{Natural=I}" },   .{ Aligned, .reference, "{Aligned}" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[2], comptime encodeStruct(@typeInfo(case[0]).@"struct", resolveStructName(case[0]), case[1]));
    }
}

test "encodeOptional" {
    const cases = .{
        .{ ?*const i32, "^i" },   .{ ?[*]const i32, "^i" },
        .{ ?[*:0]const u8, "*" }, .{ ?*const fn () callconv(.c) void, "^?" },
        .{ ?*rt.Object, "@" },    .{ ?*const ?*rt.Object, "^@" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime encodeOptional(@typeInfo(case[0]).optional));
    }
}

test "encodePointer" {
    const Handle = opaque {};
    const Point = extern struct { x: f64 };
    const Value = extern union { integer: i32, real: f64 };
    const Flags = packed struct(u32) { value: u32 };
    const cases = .{
        .{ *anyopaque, "^v" },         .{ *const Handle, "^v" },                  .{ **Handle, "^^v" },
        .{ *i8, "^c" },                .{ [*]u8, "^C" },                          .{ [*c]i32, "^i" },
        .{ *allowzero i32, "^i" },     .{ *const fn () callconv(.c) void, "^?" }, .{ *Point, "^{Point}" },
        .{ **Point, "^^{Point}" },     .{ *Value, "^(Value)" },                   .{ **Value, "^^(Value)" },
        .{ *Flags, "^I" },             .{ **rt.Object, "^@" },                    .{ *?*const rt.Object, "^@" },
        .{ ***rt.Object, "^^@" },      .{ **rt.Class, "^#" },                     .{ **rt.Sel, "^:" },
        .{ *[2]?*rt.Object, "^[2@]" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime encodePointer(@typeInfo(case[0]).pointer));
    }
}

test "resolveStructName" {
    const Types = struct {
        const struct_Point = extern struct { x: f64 };
        const union_Value = extern union { integer: i32, real: f64 };

        fn Generic(comptime T: type) type {
            return extern struct { value: T };
        }
    };
    const cases = .{
        .{ Types.struct_Point, "Point" },
        .{ Types.union_Value, "Value" },
        .{ Types.Generic(Types.struct_Point), "Generic" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime resolveStructName(case[0]));
    }
}
