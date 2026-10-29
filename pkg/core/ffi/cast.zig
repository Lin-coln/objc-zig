const std = @import("std");
const c = @import("c.zig").c;

pub const @"type" = struct {
    pub fn z2c(comptime T: type) type {
        if (T == bool) {
            return c.BOOL;
        } else {
            return T;
        }
    }

    pub fn c2z(comptime T: type) type {
        return if (T == c.BOOL) bool else T;
    }
};

pub fn z2c(val: anytype) @"type".z2c(@TypeOf(val)) {
    if (@TypeOf(val) == bool) {
        return if (val) c.YES else c.NO;
    } else {
        return val;
    }
}

pub fn c2z(val: anytype) @"type".c2z(@TypeOf(val)) {
    if (@TypeOf(val) == c.BOOL) {
        return val != c.NO;
    } else {
        return val;
    }
}

test "cast types: maps bool and BOOL without changing other types" {
    try std.testing.expect(@"type".z2c(bool) == c.BOOL);
    try std.testing.expect(@"type".c2z(c.BOOL) == bool);

    const Payload = extern struct { flag: bool };
    const Callback = *const fn (bool) callconv(.c) bool;
    inline for (.{ void, i32, f64, *bool, ?*bool, [2]bool, Payload, Callback }) |T| {
        try std.testing.expect(@"type".z2c(T) == T);
        try std.testing.expect(@"type".c2z(T) == T);
    }
}

test "z2c: converts boolean values to ABI YES and NO" {
    const values = [_]bool{ false, true };
    for (values) |value| {
        const result = z2c(value);
        try std.testing.expect(@TypeOf(result) == c.BOOL);
        try std.testing.expectEqual(if (value) c.YES else c.NO, result);
    }
}

test "c2z: normalizes zero and all tested nonzero BOOL values" {
    const values = if (c.BOOL == bool)
        [_]c.BOOL{ false, true }
    else
        [_]c.BOOL{ 0, 1, 2, -1, std.math.minInt(c.BOOL), std.math.maxInt(c.BOOL) };

    for (values) |value| {
        const result = c2z(value);
        try std.testing.expect(@TypeOf(result) == bool);
        try std.testing.expectEqual(value != c.NO, result);
    }
}

test "cast values: preserves numbers, pointers, nulls and aggregate fields" {
    const number: i32 = -42;
    try std.testing.expectEqual(number, z2c(number));
    try std.testing.expectEqual(number, c2z(number));
    const fraction: f64 = 1.25;
    try std.testing.expectEqual(fraction, z2c(fraction));
    try std.testing.expectEqual(fraction, c2z(fraction));

    var flag = true;
    try std.testing.expectEqual(&flag, z2c(&flag));
    try std.testing.expectEqual(&flag, c2z(&flag));
    const optional: ?*bool = &flag;
    try std.testing.expectEqual(optional, z2c(optional));
    try std.testing.expectEqual(optional, c2z(optional));
    const absent: ?*bool = null;
    try std.testing.expectEqual(absent, z2c(absent));
    try std.testing.expectEqual(absent, c2z(absent));

    const Payload = extern struct { flag: bool, value: i32 };
    const payload: Payload = .{ .flag = true, .value = -7 };
    try std.testing.expectEqualDeep(payload, z2c(payload));
    try std.testing.expectEqualDeep(payload, c2z(payload));
    const flags = [_]bool{ true, false };
    try std.testing.expectEqualDeep(flags, z2c(flags));
    try std.testing.expectEqualDeep(flags, c2z(flags));
}
