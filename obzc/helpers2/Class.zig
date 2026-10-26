const std = @import("std");
const ffi = @import("../ffi/root.zig");
const utils = @import("../utils/root.zig");
const calling = @import("calling.zig");

pub fn Class(comptime T: type) type {
    const class_name = comptime utils.resolveTypeName(@typeName(T));

    return struct {
        /// Calls a class method, converting top-level bool arguments and returns through BOOL.
        pub fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            return calling.call(getClass(), Return, name, args);
        }

        fn getClass() *ffi.Class {
            return ffi.Class.lookup(class_name).?;
        }
    };
}

test "helpers2.Class: getClass resolves the wrapper type" {
    const NSObject = opaque {};
    const NSNumber = opaque {};
    try std.testing.expectEqual(ffi.Class.lookup("NSObject").?, Class(NSObject).getClass());
    try std.testing.expectEqual(ffi.Class.lookup("NSNumber").?, Class(NSNumber).getClass());
}

test "helpers2.Class: call binds the receiver to its wrapper class" {
    const NSObject = opaque {};
    const NSNumber = opaque {};

    const object_class = Class(NSObject);
    const number_class = Class(NSNumber);
    try std.testing.expectEqual(ffi.Class.lookup("NSObject").?, object_class.call(*ffi.Class, "class", .{}));
    try std.testing.expectEqual(ffi.Class.lookup("NSNumber").?, number_class.call(*ffi.Class, "class", .{}));
    try std.testing.expectEqual(ffi.Class.lookup("NSObject").?, object_class.call(*ffi.Class, "class", .{}));
}
