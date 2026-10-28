const std = @import("std");
const Type = std.lang.Type;

pub fn fromInt(info: Type.Int) ?[]const u8 {
    const c: u8 = switch (info.bits) {
        8 => 'c',
        16 => 's',
        32 => 'i',
        64 => 'q',
        128 => 't',
        else => null,
    } orelse
        return null;

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
