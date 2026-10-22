const std = @import("std");
const utils = @import("utils.zig");

pub fn Method(comptime T: type, comptime Helper: type) type {
    const Receiver: ?type = utils.resolveReceiverType(T, Helper.call);

    return struct {
        pub fn of(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeMethod(name, Shape).function) {
            return makeMethod(name, Shape).function;
        }
        inline fn makeMethod(comptime name: [:0]const u8, comptime Shape: type) type {
            return @import("makeMethod.zig").makeMethod(Receiver, Helper.call, name, Shape);
        }

        // pub fn withCallback(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeWithCallback(name, Shape).function) {
        //     return makeWithCallback(name, Shape).function;
        // }
        // inline fn makeWithCallback(comptime name: [:0]const u8, comptime Shape: type) type {
        //     return @import("makeWithCallback.zig").makeWithCallback(Receiver, Helper.call, name, Shape);
        // }
    };
}
