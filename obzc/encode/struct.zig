const std = @import("std");
const Type = std.lang.Type;
const utils = @import("../utils/root.zig");

pub fn fromStruct(
    encode: anytype,
    comptime T: type,
    info: Type.Struct,
    mode: enum { val, ref },
) ?[]const u8 {
    return switch (info.layout) {
        .@"packed" => encode(info.backing_integer.?),
        .@"extern" => blk: {
            const name = resolveStructName(T);
            const content = switch (mode) {
                .ref => name,
                .val => name ++ "=" ++ resolveFields(encode, T, .{ .@"struct" = info }),
            };
            break :blk "{" ++ content ++ "}";
        },
        else => switch (mode) {
            .ref => "v",
            .val => @compileError(
                "cannot encode struct " ++
                    @typeName(T) ++
                    ":\nauto layout is not C-compatible; use an extern or packed struct",
            ),
        },
    };
}

pub fn fromUnion(
    encode: anytype,
    comptime T: type,
    info: Type.Union,
    mode: enum { val, ref },
) ?[]const u8 {
    return switch (info.layout) {
        .@"extern" => blk: {
            const name = resolveStructName(T);
            const content = switch (mode) {
                .ref => name,
                .val => name ++ "=" ++ resolveFields(encode, T, .{ .@"union" = info }),
            };
            break :blk "(" ++ content ++ ")";
        },
        else => switch (mode) {
            .ref => "v",
            .val => @compileError(
                "cannot encode union " ++
                    @typeName(T) ++
                    ":\nonly extern unions have a supported Objective-C layout",
            ),
        },
    };
}

fn resolveFields(
    encode: anytype,
    comptime T: type,
    src: union(enum) {
        @"struct": Type.Struct,
        @"union": Type.Union,
    },
) []const u8 {
    var fields: []const u8 = "";

    const types, const names, const attrs = blk: {
        switch (src) {
            .@"struct" => |info| break :blk .{ info.field_types, info.field_names, info.field_attrs },
            .@"union" => |info| break :blk .{ info.field_types, info.field_names, info.field_attrs },
        }
    };

    for (types, names, attrs) |F, field, attr| {
        const alignment = attr.@"align" orelse @alignOf(F);

        if (alignment != @alignOf(F)) {
            @compileError(std.fmt.comptimePrint(
                "cannot encode {s} {s}:\nfield {s}: alignment is {d}, natural alignment is {d}; Objective-C type encoding cannot represent custom field alignment",
                .{
                    switch (src) {
                        .@"struct" => "struct",
                        .@"union" => "union",
                    },
                    @typeName(T),
                    field,
                    alignment,
                    @alignOf(F),
                },
            ));
        }

        fields = fields ++ encode(F);
    }

    return fields;
}

/// Removes translate-c's aggregate tag prefixes from the resolved type name.
fn resolveStructName(comptime T: type) []const u8 {
    const name = utils.resolveTypeName(@typeName(T));
    if (std.mem.startsWith(u8, name, "struct_")) return name["struct_".len..];
    if (std.mem.startsWith(u8, name, "union_")) return name["union_".len..];
    return name;
}

test "fromStruct: formats extern values and references, packed backing, and auto references" {
    const Stub = struct {
        fn encode(comptime T: type) []const u8 {
            return if (T == u8) "C" else "I";
        }
    };
    const Point = extern struct { x: u8, y: u32 };
    const Packed = packed struct(u32) { value: u32 };
    const Auto = struct { value: u32 };

    try std.testing.expectEqualStrings("{Point=CI}", comptime fromStruct(Stub.encode, Point, @typeInfo(Point).@"struct", .val).?);
    try std.testing.expectEqualStrings("{Point}", comptime fromStruct(Stub.encode, Point, @typeInfo(Point).@"struct", .ref).?);
    try std.testing.expectEqualStrings("I", comptime fromStruct(Stub.encode, Packed, @typeInfo(Packed).@"struct", .val).?);
    try std.testing.expectEqualStrings("v", comptime fromStruct(Stub.encode, Auto, @typeInfo(Auto).@"struct", .ref).?);
}

test "fromUnion: formats extern values and references and auto references" {
    const Stub = struct {
        fn encode(comptime T: type) []const u8 {
            return if (T == u8) "C" else "I";
        }
    };
    const Value = extern union { byte: u8, word: u32 };
    const Auto = union { byte: u8, word: u32 };

    try std.testing.expectEqualStrings("(Value=CI)", comptime fromUnion(Stub.encode, Value, @typeInfo(Value).@"union", .val).?);
    try std.testing.expectEqualStrings("(Value)", comptime fromUnion(Stub.encode, Value, @typeInfo(Value).@"union", .ref).?);
    try std.testing.expectEqualStrings("v", comptime fromUnion(Stub.encode, Auto, @typeInfo(Auto).@"union", .ref).?);
}

test "resolveFields: keeps aggregate field order" {
    const Stub = struct {
        fn encode(comptime T: type) []const u8 {
            return if (T == u8) "C" else "I";
        }
    };
    const Fields = extern struct { first: u32, second: u8 };
    try std.testing.expectEqualStrings("IC", comptime resolveFields(Stub.encode, Fields, .{ .@"struct" = @typeInfo(Fields).@"struct" }));
}

test "resolveStructName: strips translated aggregate prefixes" {
    const Names = struct {
        const struct_Point = extern struct { value: u8 };
        const union_Value = extern union { value: u8 };
    };
    try std.testing.expectEqualStrings("Point", comptime resolveStructName(Names.struct_Point));
    try std.testing.expectEqualStrings("Value", comptime resolveStructName(Names.union_Value));
}
