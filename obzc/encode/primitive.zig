const std = @import("std");
const Type = std.lang.Type;

pub fn fromInt(info: Type.Int) ?[]const u8 {
    const c: u8 = switch (info.bits) {
        8 => 'c',
        16 => 's',
        32 => 'i',
        64 => 'q',
        128 => 't',
        else => return null,
    };

    const C: u8 = switch (info.signedness) {
        .signed => c,
        .unsigned => std.ascii.toUpper(c),
    };

    return &.{C};
}

pub fn fromFloat(info: Type.Float) ?[]const u8 {
    return switch (info.bits) {
        32 => "f",
        64 => "d",
        // c_longdouble => "D",
        else => null,
    };
}

test "fromInt: maps width and signedness" {
    const cases = .{
        .{ i8, "c" },   .{ u8, "C" },   .{ i16, "s" }, .{ u16, "S" },
        .{ i32, "i" },  .{ u32, "I" },  .{ i64, "q" }, .{ u64, "Q" },
        .{ i128, "t" }, .{ u128, "T" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime fromInt(@typeInfo(case[0]).int).?);
    }
    try std.testing.expectEqual(null, comptime fromInt(@typeInfo(u7).int));
}

test "fromFloat: maps supported widths" {
    try std.testing.expectEqualStrings("f", comptime fromFloat(@typeInfo(f32).float).?);
    try std.testing.expectEqualStrings("d", comptime fromFloat(@typeInfo(f64).float).?);
    try std.testing.expectEqual(null, comptime fromFloat(@typeInfo(f16).float));
}
