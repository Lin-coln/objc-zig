const std = @import("std");
const utils = @import("../../utils/root.zig");

pub fn method(comptime T: type, comptime call: anytype) type {
    const Receiver: ?type = utils.resolveReceiverType(T, call);

    return struct {
        pub fn of(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeMethod(name, Shape).function) {
            return makeMethod(name, Shape).function;
        }
        inline fn makeMethod(comptime name: [:0]const u8, comptime Shape: type) type {
            return @import("makeMethod.zig").makeMethod(Receiver, call, name, Shape);
        }

        pub fn withCallback(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeWithCallback(name, Shape).function) {
            return makeWithCallback(name, Shape).function;
        }
        inline fn makeWithCallback(comptime name: [:0]const u8, comptime Shape: type) type {
            return @import("makeWithCallback.zig").makeWithCallback(Receiver, call, name, Shape);
        }

        pub fn withSync(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeWithSync(name, Shape).function) {
            return makeWithSync(name, Shape).function;
        }
        inline fn makeWithSync(comptime name: [:0]const u8, comptime Shape: type) type {
            return @import("makeWithSync.zig").makeWithSync(Receiver, call, name, Shape);
        }
    };
}

test "helpers.method.of: binds the supplied call function and selector" {
    const Wrapped = opaque {};
    const First = struct {
        var selector: []const u8 = "";

        fn call(comptime Return: type, name: [:0]const u8, _: anytype) Return {
            selector = name;
            return 11;
        }
    };
    const Second = struct {
        var selector: []const u8 = "";

        fn call(comptime Return: type, name: [:0]const u8, _: anytype) Return {
            selector = name;
            return 23;
        }
    };
    const first = method(Wrapped, First.call).of("firstValue", fn () usize);
    const second = method(Wrapped, Second.call).of("secondValue", fn () usize);

    try std.testing.expectEqual(@as(usize, 11), first());
    try std.testing.expectEqualStrings("firstValue", First.selector);
    try std.testing.expectEqual(@as(usize, 23), second());
    try std.testing.expectEqualStrings("secondValue", Second.selector);
}

test {
    _ = @import("makeMethod.zig");
    _ = @import("makeWithCallback.zig");
    _ = @import("makeWithSync.zig");
    _ = @import("initBlockWithContext.zig");
    _ = @import("spreadForCallback.zig");
}
