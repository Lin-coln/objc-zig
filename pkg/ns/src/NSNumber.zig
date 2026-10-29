const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;

pub const NSNumber = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub fn init(comptime T: type, value: T) *Self {
        const selector: [:0]const u8 = switch (T) {
            isize => "initWithInteger:",
            f64 => "initWithDouble:",
            bool => "initWithBool:",
            else => @compileError("NSNumber.init supports only isize, f64, and bool"),
        };

        const allocated: *Self = h.cls.alloc();
        return h.call(allocated, ?*Self, selector, .{value}).?;
    }

    pub fn as(self: *Self, comptime T: type) T {
        const name: [:0]const u8 = switch (T) {
            isize => "integerValue",
            f64 => "doubleValue",
            bool => "boolValue",
            else => @compileError("NSNumber.as supports only isize, f64, and bool"),
        };

        return h.prop(name, T).getter(self);
    }
};

test "NSNumber: integer, double, and bool values" {
    const integer = NSNumber.init(isize, 42);
    defer integer.release();
    const double = NSNumber.init(f64, 1.3);
    defer double.release();
    const yes = NSNumber.init(bool, true);
    defer yes.release();
    const no = NSNumber.init(bool, false);
    defer no.release();

    try std.testing.expectEqual(42, integer.as(isize));
    try std.testing.expectEqual(1.3, double.as(f64));
    try std.testing.expectEqual(1, double.as(isize));
    try std.testing.expect(yes.as(bool));
    try std.testing.expect(!no.as(bool));

    const retained = integer.retain();
    defer retained.release();
    try std.testing.expectEqual(integer, retained);
}

test "NSNumber: signed integer limits round-trip without narrowing" {
    for ([_]isize{ std.math.minInt(isize), -1, std.math.maxInt(isize) }) |value| {
        const number = NSNumber.init(isize, value);
        defer number.release();

        try std.testing.expectEqual(value, number.as(isize));
    }
}
