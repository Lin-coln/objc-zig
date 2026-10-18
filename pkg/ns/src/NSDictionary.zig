const std = @import("std");
const objc = @import("objc");

pub fn NSDictionary(comptime Key: type, comptime Value: type) type {
    return opaque {
        const Self = @This();
        const h = objc.helpers.Object(Self);

        pub const retain = h.retain;
        pub const release = h.release;
        pub const new = h.cls.new;

        /// Copies the keys and retains the values. Keys must conform to NSCopying.
        pub fn init(objects: []const *Value, keys: []const *Key) *Self {
            std.debug.assert(objects.len == keys.len);
            const initialize = h.method("initWithObjects:forKeys:count:", fn ([*]const *Value, [*]const *Key, usize) *Self);
            return initialize(h.cls.alloc(), objects.ptr, keys.ptr, objects.len);
        }

        pub const count = h.prop(usize, "count").getter;

        /// Returns a borrowed value, or null when the key is absent.
        pub const objectForKey = h.method("objectForKey:", fn (*Key) ?*Value);
    };
}

test "NSDictionary: new creates an empty dictionary" {
    const NSString = @import("NSString.zig").NSString;
    const dictionary = NSDictionary(NSString, NSString).new();
    defer dictionary.release();
    const key = NSString.init("missing").?;
    defer key.release();

    try std.testing.expectEqual(0, dictionary.count());
    try std.testing.expect(dictionary.objectForKey(key) == null);
}

test "NSDictionary: init and objectForKey preserve key-value pairs" {
    const NSString = @import("NSString.zig").NSString;
    const NSNumber = @import("NSNumber.zig").NSNumber;
    const dictionary = initialized: {
        const first_key = NSString.init("first dictionary key").?;
        defer first_key.release();
        const second_key = NSString.init("second dictionary key").?;
        defer second_key.release();
        const first_value = NSNumber.init(isize, 42);
        defer first_value.release();
        const second_value = NSNumber.init(isize, 7);
        defer second_value.release();

        break :initialized NSDictionary(NSString, NSNumber).init(&.{ first_value, second_value }, &.{ first_key, second_key });
    };
    defer dictionary.release();

    const first_key = NSString.init("first dictionary key").?;
    defer first_key.release();
    const second_key = NSString.init("second dictionary key").?;
    defer second_key.release();
    const missing_key = NSString.init("missing").?;
    defer missing_key.release();

    try std.testing.expectEqual(2, dictionary.count());
    try std.testing.expectEqual(42, dictionary.objectForKey(first_key).?.as(isize));
    try std.testing.expectEqual(7, dictionary.objectForKey(second_key).?.as(isize));
    try std.testing.expect(dictionary.objectForKey(missing_key) == null);
}
