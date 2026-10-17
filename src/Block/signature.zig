const std = @import("std");
const rt = @import("../rt/root.zig");
const encode = @import("encode.zig").encode;

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
    var signature: []const u8 = encode(fn_info.return_type.?) ++ "@?";
    for (fn_info.param_types) |T| signature = signature ++ encode(T.?);
    return std.fmt.comptimePrint("{s}", .{signature});
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
