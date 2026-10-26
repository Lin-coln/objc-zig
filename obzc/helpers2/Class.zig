const ffi = @import("../ffi/root.zig");
const utils = @import("../utils/root.zig");

pub fn Class(comptime T: type) type {
    const class_name = comptime utils.resolveTypeName(@typeName(T));

    return struct {
        /// Calls a class method, converting top-level bool arguments and returns through BOOL.
        pub fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            return @import("calling.zig").call(getClass(), Return, name, args);
        }

        fn getClass() *ffi.Class {
            return ffi.Class.lookup(class_name).?;
        }
    };
}

test "helpers2.Class: lookup and class calls preserve BOOL and nullable results" {
    const std = @import("std");
    const NSObject = opaque {};
    const NSNumber = opaque {};
    const pool = ffi.c.objc_autoreleasePoolPush();
    defer ffi.c.objc_autoreleasePoolPop(pool);

    const h = Class(NSNumber);
    try std.testing.expectEqual(ffi.Class.lookup("NSNumber").?, h.getClass());
    const number = h.call(*ffi.Object, "numberWithBool:", .{true});
    try std.testing.expectEqual(ffi.c.YES, ffi.msg.send(number, ffi.c.BOOL, ffi.Sel.get("boolValue"), .{}));
    try std.testing.expect(h.call(bool, "instancesRespondToSelector:", .{ffi.Sel.get("boolValue")}));
    try std.testing.expect(!h.call(bool, "instancesRespondToSelector:", .{ffi.Sel.get("obzcHelpers2MissingMethod")}));
    try std.testing.expectEqual(null, Class(NSObject).call(?*ffi.Class, "superclass", .{}));
}
