const std = @import("std");
const objc = @import("../root.zig");

pub fn NSArray(comptime T: type) type {
    return opaque {
        const Self = @This();
        const h = objc.helpers.Object(Self);

        pub const retain = h.retain;
        pub const release = h.release;

        pub fn init(objects: []const *T) *Self {
            const allocated: *Self = @ptrCast(objc.getClass("NSArray").?.alloc());
            return h.msgSend(allocated, ?*Self, "initWithObjects:count:", .{ objects.ptr, objects.len }).?;
        }

        pub const getCount = h.prop(usize, "count").getter;

        /// The returned object is borrowed from the array.
        pub fn objectAtIndex(self: *Self, index: usize) *T {
            return h.msgSend(self, ?*T, "objectAtIndex:", .{index}).?;
        }
    };
}

test "NSArray: create and read objects" {
    const NSString = @import("NSString.zig").NSString;
    const first = NSString.init("first").?;
    defer first.release();
    const second = NSString.init("second").?;
    defer second.release();

    const objects = [_]*NSString{ first, second };
    const array = NSArray(NSString).init(&objects);
    defer array.release();

    try std.testing.expectEqual(2, array.getCount());
    try std.testing.expectEqualStrings("first", array.objectAtIndex(0).getUTF8String());
    try std.testing.expectEqualStrings("second", array.objectAtIndex(1).getUTF8String());
}
