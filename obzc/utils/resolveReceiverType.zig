const std = @import("std");

pub fn resolveReceiverType(comptime T: type, comptime call: anytype) ?type {
    const info_call = switch (@typeInfo(@TypeOf(call))) {
        .@"fn" => |info| info,
        else => @compileError("call should be a fn"),
    };

    const Receiver: ?type = blk: {
        if (info_call.param_types.len < 1) break :blk null;
        const Arg0 = info_call.param_types[0] orelse break :blk null;
        const matches = switch (@typeInfo(Arg0)) {
            // *T or *const T
            .pointer => |ptr| ptr.size == .one and ptr.child == T,
            // T
            else => Arg0 == T,
        };
        break :blk if (matches) Arg0 else null;
    };

    return Receiver;
}

test "resolveReceiverType identifies supported receiver forms" {
    const T = struct {};
    const Calls = struct {
        fn noArgs() void {}
        fn generic(_: anytype) void {}
        fn other(_: *u8) void {}
        fn many(_: [*]T) void {}
        fn mutable(_: *T) void {}
        fn immutable(_: *const T) void {}
        fn value(_: T) void {}
    };

    try std.testing.expect(resolveReceiverType(T, Calls.noArgs) == null);
    try std.testing.expect(resolveReceiverType(T, Calls.generic) == null);
    try std.testing.expect(resolveReceiverType(T, Calls.other) == null);
    try std.testing.expect(resolveReceiverType(T, Calls.many) == null);
    try std.testing.expect(resolveReceiverType(T, Calls.mutable) == *T);
    try std.testing.expect(resolveReceiverType(T, Calls.immutable) == *const T);
    try std.testing.expect(resolveReceiverType(T, Calls.value) == T);
}
