const std = @import("std");
const rt = @import("../rt/root.zig");

/// Encodes the return type, the implicit block argument, then the function parameters.
/// Sizes and offsets are omitted, matching the type-only signatures used by Block.
pub fn generateFromFnType(comptime Fn: type) [:0]const u8 {
    const fn_info = switch (@typeInfo(Fn)) {
        .@"fn" => |info| info,
        else => @compileError("expected a function type, got " ++ @typeName(Fn)),
    };
    if (fn_info.is_generic or fn_info.attrs.varargs) {
        @compileError("a block signature requires a non-generic function with fixed parameters");
    }
    var signature: []const u8 = encodeType(fn_info.return_type.?) ++ "@?";
    for (fn_info.param_types) |T| signature = signature ++ encodeType(T.?);
    return std.fmt.comptimePrint("{s}", .{signature});
}

/// Objective-C type encoding of `T`. Integers are encoded by width so the result does not depend on the target's `long`.
fn encodeType(comptime T: type) []const u8 {
    return switch (T) {
        void, anyopaque => "v",
        bool => "B",
        f32 => "f",
        f64 => "d",
        c_longdouble => "D",
        *rt.Object, ?*rt.Object => "@",
        *rt.Class, ?*rt.Class => "#",
        *rt.Sel, ?*rt.Sel => ":",
        [*:0]u8, [*:0]const u8, ?[*:0]u8, ?[*:0]const u8, [*c]u8, [*c]const u8 => "*",
        else => switch (@typeInfo(T)) {
            .int => |int| switch (int.bits) {
                8 => if (int.signedness == .signed) "c" else "C",
                16 => if (int.signedness == .signed) "s" else "S",
                32 => if (int.signedness == .signed) "i" else "I",
                64 => if (int.signedness == .signed) "q" else "Q",
                else => @compileError("no Objective-C type encoding for " ++ @typeName(T)),
            },
            .@"enum" => |info| encodeType(info.tag_type),
            .optional => |info| if (@typeInfo(info.child) == .pointer) encodeType(info.child) else @compileError("no Objective-C type encoding for " ++ @typeName(T)),
            .pointer => |info| switch (info.size) {
                .slice => @compileError("no Objective-C type encoding for " ++ @typeName(T)),
                // Pointers to structs only name the struct, which also keeps self-referential structs finite.
                else => switch (@typeInfo(info.child)) {
                    .@"fn" => "^?",
                    .@"opaque" => "^v",
                    .@"struct" => |s| if (s.layout == .@"extern") "^{" ++ getStructName(info.child) ++ "}" else "^" ++ encodeType(info.child),
                    else => "^" ++ encodeType(info.child),
                },
            },
            .@"struct" => |info| switch (info.layout) {
                .@"extern" => blk: {
                    var fields: []const u8 = "";
                    for (info.field_types) |F| fields = fields ++ encodeType(F);
                    break :blk "{" ++ getStructName(T) ++ "=" ++ fields ++ "}";
                },
                .@"packed" => encodeType(info.backing_integer.?),
                .auto => @compileError("no Objective-C type encoding for non-extern struct " ++ @typeName(T)),
            },
            .array => |info| std.fmt.comptimePrint("[{d}{s}]", .{ info.len, encodeType(info.child) }),
            else => @compileError("no Objective-C type encoding for " ++ @typeName(T)),
        },
    };
}

/// Resolves the struct tag without namespaces or type factory arguments.
/// translate-c prefixes C struct tags with `struct_`.
fn getStructName(comptime T: type) []const u8 {
    const full = @typeName(T);
    var start: usize = 0;
    var end: usize = full.len;
    var depth: usize = 0;
    var quoted = false;
    var escaped = false;

    for (full, 0..) |char, i| {
        if (quoted) {
            if (escaped) {
                escaped = false;
            } else if (char == '\\') {
                escaped = true;
            } else if (char == '"') {
                quoted = false;
            }
            continue;
        }
        switch (char) {
            '"' => quoted = true,
            '(' => {
                if (depth == 0) end = i;
                depth += 1;
            },
            ')' => depth -= 1,
            '.' => if (depth == 0) {
                start = i + 1;
                end = full.len;
            },
            else => {},
        }
    }
    const name = full[start..end];
    return if (std.mem.startsWith(u8, name, "struct_")) name["struct_".len..] else name;
}

test "generateFromFnType: scalars, pointers and aggregates" {
    const Kind = enum(u16) { value };
    const Point = extern struct { x: f64, y: f64 };
    const Node = extern struct { next: ?*@This(), value: i32 };
    const cases = .{
        .{ fn () void, "v@?" },
        .{ fn (bool, i8, u8, i16, u16, i32, u32, i64, u64, f32, f64) bool, "B@?BcCsSiIqQfd" },
        .{ fn (*rt.Object, ?*rt.Object, *rt.Class, ?*rt.Class, *rt.Sel, ?*rt.Sel) void, "v@?@@##::" },
        .{ fn ([*:0]const u8, ?[*:0]u8, [*c]const u8, ?*anyopaque, *const u32, ?*const fn () callconv(.c) void) void, "v@?***^v^I^?" },
        .{ fn (Kind, Point, [4]u8) Point, "{Point=dd}@?S{Point=dd}[4C]" },
        .{ fn (*const Node) Node, "{Node=^{Node}i}@?^{Node}" },
    };
    inline for (cases) |case| {
        const signature = comptime generateFromFnType(case[0]);
        try std.testing.expectEqualStrings(case[1], signature);
        try std.testing.expectEqual(@as(u8, 0), signature.ptr[signature.len]);
    }
}

test "getStructName: translated and generated structs" {
    @setEvalBranchQuota(10000);
    const Types = struct {
        const struct_Point = extern struct { x: f64 };

        fn Generic(comptime T: type) type {
            return extern struct { value: T };
        }

        fn Text(comptime text: []const u8) type {
            return extern struct {
                const label = text;
                value: u32,
            };
        }

        fn Namespace(comptime T: type) type {
            return struct {
                const Point = extern struct { value: T };
            };
        }
    };
    const cases = .{
        .{ Types.struct_Point, "Point" },
        .{ Types.Generic(u32), "Generic" },
        .{ Types.Generic(Types.struct_Point), "Generic" },
        .{ Types.Generic(Types.Generic(Types.struct_Point)), "Generic" },
        .{ Types.Text("a)b.c"), "Text" },
        .{ Types.Text("a(b.c"), "Text" },
        .{ Types.Text("a\"b).c"), "Text" },
        .{ Types.Namespace(u32).Point, "Point" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime getStructName(case[0]));
    }
    try std.testing.expectEqualStrings("{Generic=I}@?", comptime generateFromFnType(fn () Types.Generic(u32)));
}
