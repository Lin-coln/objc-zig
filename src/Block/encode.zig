const std = @import("std");
const rt = @import("../rt/root.zig");
const utils = @import("../utils.zig");
const Type = std.lang.Type;

/// Returns the Objective-C encoding of a Zig type, e.g. `i32` -> `i`, `*i32` -> `^i`.
/// Unsupported types produce a compile error here; internal encoders return null.
pub fn encode(comptime T: type) []const u8 {
    const encoded = comptime encodeAnytype(T);
    return encoded orelse @compileError("no Objective-C type encoding for " ++ @typeName(T));
}

/// Matches runtime Object/Class/Sel pointers as `@`/`#`/`:` before general types.
/// Fixed encodings: void/bool/f32/f64/c_longdouble -> `v`/`B`/`f`/`d`/`D`;
/// sentinel and C u8 pointers -> `*`. Enums use their tag type; arrays use `[countElement]`.
/// All recursive encoders return here to apply the same rules to nested types.
/// Returns null when a type or an array element cannot be encoded.
fn encodeAnytype(comptime T: type) ?[]const u8 {
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

    encoded = switch (@typeInfo(T)) {
        .int => |info| encodeInt(info),
        .@"enum" => |info| encodeAnytype(info.tag_type),
        .@"union" => |info| encodeUnion(info, resolveStructName(T), .value),
        .@"struct" => |info| encodeStruct(info, resolveStructName(T), .value),
        .optional => |info| encodeOptional(info),
        .pointer => encodePointer(T),
        .array => |info| blk: {
            const element = encodeAnytype(info.child) orelse break :blk null;
            break :blk std.fmt.comptimePrint("[{d}{s}]", .{ info.len, element });
        },
        else => null,
    };
    return encoded;
}

/// Signed 8/16/32/64/128-bit integers -> `c`/`s`/`i`/`q`/`t`;
/// unsigned equivalents -> `C`/`S`/`I`/`Q`/`T`. Other widths return null.
/// Encoding follows bit width, independently of the target's `long`.
fn encodeInt(int: Type.Int) ?[]const u8 {
    return switch (int.bits) {
        8 => if (int.signedness == .signed) "c" else "C",
        16 => if (int.signedness == .signed) "s" else "S",
        32 => if (int.signedness == .signed) "i" else "I",
        64 => if (int.signedness == .signed) "q" else "Q",
        128 => if (int.signedness == .signed) "t" else "T",
        else => null,
    };
}

/// Extern union: .value -> `(Name=Fields)`, .reference -> `(Name)`.
/// Only .value encodes members; references stop before self-referential fields.
/// Non-extern unions or unsupported value members return null.
fn encodeUnion(info: Type.Union, name: []const u8, mode: enum { value, reference }) ?[]const u8 {
    if (info.layout != .@"extern") return null;
    if (mode == .reference) return "(" ++ name ++ ")";
    var fields: []const u8 = "";
    for (info.field_types) |F| fields = fields ++ (encodeAnytype(F) orelse return null);
    return "(" ++ name ++ "=" ++ fields ++ ")";
}

/// Extern struct: .value -> `{Name=Fields}`, .reference -> `{Name}` without traversing fields.
/// Packed structs use their backing integer encoding in both modes, e.g. packed(u32) -> `I`.
/// Auto-layout structs or unsupported value fields return null.
fn encodeStruct(info: Type.Struct, name: []const u8, mode: enum { value, reference }) ?[]const u8 {
    return switch (info.layout) {
        .auto => null,
        .@"packed" => encodeAnytype(info.backing_integer.?),
        .@"extern" => blk: {
            if (mode == .reference) break :blk "{" ++ name ++ "}";
            var fields: []const u8 = "";
            for (info.field_types) |F| fields = fields ++ (encodeAnytype(F) orelse return null);
            break :blk "{" ++ name ++ "=" ++ fields ++ "}";
        },
    };
}

/// Nullable one/many pointers reuse their child's encoding: `?*i32` -> `^i`.
/// Slices, C pointers and allowzero pointers cannot reuse a single pointer's representation.
/// Those cases and non-pointer optionals return null.
fn encodeOptional(info: Type.Optional) ?[]const u8 {
    if (@typeInfo(info.child) != .pointer) return null;
    const pointer = @typeInfo(info.child).pointer;
    if (pointer.size == .slice or pointer.size == .c or pointer.attrs.@"allowzero") return null;
    return encodeAnytype(info.child);
}

/// Prepends `^` to the pointee encoding; functions -> `^?`, opaque types -> `^v`.
/// Struct/union references omit fields (`^{Name}`/`^(Name)`); packed struct pointers use `^Integer`.
/// Slices contain a pointer and length, so they and unsupported pointees return null.
/// Fixed object and string pointer encodings are handled earlier by encodeAnytype.
fn encodePointer(comptime T: type) ?[]const u8 {
    const info = @typeInfo(T).pointer;
    if (info.size == .slice) return null;
    const Child = info.child;

    return switch (@typeInfo(Child)) {
        .@"fn" => "^?",
        .@"opaque" => "^v",
        .@"struct" => |s| "^" ++ (encodeStruct(s, resolveStructName(Child), .reference) orelse return null),
        .@"union" => |u| "^" ++ (encodeUnion(u, resolveStructName(Child), .reference) orelse return null),
        else => "^" ++ (encodeAnytype(Child) orelse return null),
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
    try std.testing.expectEqualStrings("{Record=^?[2S]@}", comptime encode(Record));
}

test "encodeAnytype" {
    const Kind = enum(u16) { value };
    const Auto = struct { value: u8 };
    const cases = .{
        .{ *rt.Object, "@" },   .{ *const rt.Object, "@" }, .{ ?*rt.Object, "@" },    .{ ?*const rt.Object, "@" },
        .{ *rt.Class, "#" },    .{ *const rt.Class, "#" },  .{ ?*rt.Class, "#" },     .{ ?*const rt.Class, "#" },
        .{ *rt.Sel, ":" },      .{ *const rt.Sel, ":" },    .{ ?*rt.Sel, ":" },       .{ ?*const rt.Sel, ":" },
        .{ void, "v" },         .{ bool, "B" },             .{ f32, "f" },            .{ f64, "d" },
        .{ c_longdouble, "D" }, .{ [*:0]u8, "*" },          .{ [*:0]const u8, "*" },  .{ [*c]u8, "*" },
        .{ [*c]const u8, "*" }, .{ Kind, "S" },             .{ [2][4]u8, "[2[4C]]" }, .{ [2]?*rt.Object, "[2@]" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], (comptime encodeAnytype(case[0])).?);
    }
    inline for (.{ anyopaque, fn () void, [2]Auto, [2]?u32 }) |T| {
        try std.testing.expect(comptime encodeAnytype(T) == null);
    }
}

test "encodeInt" {
    const cases = .{
        .{ i8, "c" },   .{ u8, "C" },   .{ i16, "s" }, .{ u16, "S" },
        .{ i32, "i" },  .{ u32, "I" },  .{ i64, "q" }, .{ u64, "Q" },
        .{ i128, "t" }, .{ u128, "T" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], (comptime encodeInt(@typeInfo(case[0]).int)).?);
    }
    inline for (.{ u0, u7, u24, u256 }) |T| {
        try std.testing.expect(comptime encodeInt(@typeInfo(T).int) == null);
    }
}

test "encodeUnion" {
    const Value = extern union { integer: i32, bytes: [4]u8, object: ?*rt.Object };
    const Link = extern union { next: ?*@This(), value: i32 };
    const Auto = struct { value: u8 };
    const Unsupported = extern union { pointer: *Auto };
    const Plain = union { value: u8 };
    const Tagged = union(enum) { value: u8 };

    try std.testing.expectEqualStrings("(Value=i[4C]@)", (comptime encodeUnion(@typeInfo(Value).@"union", "Value", .value)).?);
    try std.testing.expectEqualStrings("(Value)", (comptime encodeUnion(@typeInfo(Value).@"union", "Value", .reference)).?);
    try std.testing.expectEqualStrings("(Link=^(Link)i)", (comptime encodeUnion(@typeInfo(Link).@"union", "Link", .value)).?);
    try std.testing.expect(comptime encodeUnion(@typeInfo(Unsupported).@"union", "Unsupported", .value) == null);
    try std.testing.expectEqualStrings("(Unsupported)", (comptime encodeUnion(@typeInfo(Unsupported).@"union", "Unsupported", .reference)).?);
    inline for (.{ Plain, Tagged }) |T| {
        try std.testing.expect(comptime encodeUnion(@typeInfo(T).@"union", "Unsupported", .value) == null);
        try std.testing.expect(comptime encodeUnion(@typeInfo(T).@"union", "Unsupported", .reference) == null);
    }
}

test "encodeStruct" {
    const Point = extern struct { x: f64, y: f64 };
    const Node = extern struct { next: ?*@This(), value: i32 };
    const Handles = extern struct { object: ?*rt.Object, class: *const rt.Class, selector: ?*rt.Sel };
    const Flags = packed struct(u32) { value: u32 };
    const Auto = struct { value: u8 };
    const Unsupported = extern struct { pointer: *Auto };
    const cases = .{
        .{ Point, .value, "{Point=dd}" },      .{ Point, .reference, "{Point}" },
        .{ Node, .value, "{Node=^{Node}i}" },  .{ Node, .reference, "{Node}" },
        .{ Handles, .value, "{Handles=@#:}" }, .{ Flags, .value, "I" },
        .{ Flags, .reference, "I" },           .{ Unsupported, .reference, "{Unsupported}" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[2], (comptime encodeStruct(@typeInfo(case[0]).@"struct", resolveStructName(case[0]), case[1])).?);
    }
    try std.testing.expect(comptime encodeStruct(@typeInfo(Unsupported).@"struct", "Unsupported", .value) == null);
    try std.testing.expect(comptime encodeStruct(@typeInfo(Auto).@"struct", "Auto", .value) == null);
    try std.testing.expect(comptime encodeStruct(@typeInfo(Auto).@"struct", "Auto", .reference) == null);
}

test "encodeOptional" {
    const Auto = struct { value: u8 };
    const cases = .{
        .{ ?*const i32, "^i" },   .{ ?[*]const i32, "^i" },
        .{ ?[*:0]const u8, "*" }, .{ ?*const fn () callconv(.c) void, "^?" },
        .{ ?*rt.Object, "@" },    .{ ?*const ?*rt.Object, "^@" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], (comptime encodeOptional(@typeInfo(case[0]).optional)).?);
    }
    inline for (.{ ?u32, ?bool, ?Auto, ?[]const u8, ?[*c]u8, ?*allowzero i32, ??*i32 }) |T| {
        try std.testing.expect(comptime encodeOptional(@typeInfo(T).optional) == null);
    }
}

test "encodePointer" {
    const Handle = opaque {};
    const Point = extern struct { x: f64 };
    const Value = extern union { integer: i32, real: f64 };
    const Flags = packed struct(u32) { value: u32 };
    const Auto = struct { value: u8 };
    const Tagged = union(enum) { value: u8 };
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
        try std.testing.expectEqualStrings(case[1], (comptime encodePointer(case[0])).?);
    }
    inline for (.{ []const u8, [:0]const u8, *Auto, *Tagged }) |T| {
        try std.testing.expect(comptime encodePointer(T) == null);
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
