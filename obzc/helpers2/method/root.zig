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
    };
}

test "helpers2.method.of: binds the supplied call function and selector" {
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
}
