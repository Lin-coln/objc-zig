const std = @import("std");
const utils = @import("../../utils/root.zig");
const toSpreadedFn = @import("../../utils/root.zig").toSpreadedFn;

pub fn makeMethod(
    comptime Receiver: ?type,
    comptime call: anytype,
    comptime name: [:0]const u8,
    comptime Shape: type,
) type {
    const Resolved = resolveFromShape(Shape);

    const Args = if (Receiver) |R| @Tuple(&([_]type{R} ++ Resolved.types)) else @Tuple(&Resolved.types);

    return struct {
        pub const function = toSpreadedFn(invoke, .{ .cc = Resolved.cc });
        fn invoke(args: Args) Resolved.Return {
            if (comptime Receiver != null) {
                const CallArgs = @Tuple(&Resolved.types);
                var call_args: CallArgs = undefined;
                inline for (0..Resolved.types.len) |i| {
                    call_args[i] = args[i + 1];
                }
                return call(args[0], Resolved.Return, name, call_args);
            } else {
                return call(Resolved.Return, name, args);
            }
        }
    };
}

pub fn resolveFromShape(comptime Shape: type) type {
    const info = utils.resolveFnInfo(Shape, .{});

    comptime var param_types: [info.param_types.len]type = undefined;
    inline for (info.param_types, 0..) |p_type, i| {
        param_types[i] = p_type.?;
    }
    const resolved_types = param_types;

    return struct {
        pub const types = resolved_types;
        pub const cc = info.attrs.@"callconv";
        pub const Return = info.return_type.?;
    };
}

test "helpers2.makeMethod: forwards class arguments without adding a receiver" {
    const Recorder = struct {
        var selector: []const u8 = "";
        var received: struct { value: i32, scale: f64 } = undefined;

        fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            selector = name;
            received = .{ .value = args[0], .scale = args[1] };
            return 29;
        }
    };
    const Shape = fn (i32, f64) callconv(.c) i32;
    const function = makeMethod(null, Recorder.call, "value:scale:", Shape).function;

    try std.testing.expect(@TypeOf(function) == Shape);
    try std.testing.expectEqual(@as(i32, 29), function(-7, 2.5));
    try std.testing.expectEqualStrings("value:scale:", Recorder.selector);
    try std.testing.expectEqual(@as(i32, -7), Recorder.received.value);
    try std.testing.expectEqual(@as(f64, 2.5), Recorder.received.scale);
}

test "helpers2.makeMethod: extracts the receiver before forwarding method arguments" {
    const Receiver = struct {};
    const Recorder = struct {
        var receiver: ?*Receiver = null;
        var selector: []const u8 = "";
        var received: struct { value: i32, scale: f64 } = undefined;

        fn call(self: *Receiver, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            receiver = self;
            selector = name;
            received = .{ .value = args[0], .scale = args[1] };
            return null;
        }
    };
    const function = makeMethod(*Receiver, Recorder.call, "value:scale:", fn (i32, f64) ?*Receiver).function;
    var receiver: Receiver = .{};

    try std.testing.expect(@TypeOf(function) == fn (*Receiver, i32, f64) ?*Receiver);
    try std.testing.expectEqual(null, function(&receiver, -11, 1.25));
    try std.testing.expectEqual(&receiver, Recorder.receiver.?);
    try std.testing.expectEqualStrings("value:scale:", Recorder.selector);
    try std.testing.expectEqual(@as(i32, -11), Recorder.received.value);
    try std.testing.expectEqual(@as(f64, 1.25), Recorder.received.scale);
}

test "helpers2.makeMethod: receiver-only and static calls forward an empty argument tuple" {
    const Receiver = struct {};
    const Static = struct {
        var argument_count: usize = 99;

        fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            argument_count = args.len;
        }
    };
    const Instance = struct {
        var receiver: ?*Receiver = null;
        var argument_count: usize = 99;

        fn call(self: *Receiver, comptime Return: type, _: [:0]const u8, args: anytype) Return {
            receiver = self;
            argument_count = args.len;
        }
    };
    const static = makeMethod(null, Static.call, "run", fn () void).function;
    const instance = makeMethod(*Receiver, Instance.call, "run", fn () void).function;
    var receiver: Receiver = .{};
    static();
    instance(&receiver);
    try std.testing.expectEqual(@as(usize, 0), Static.argument_count);
    try std.testing.expectEqual(@as(usize, 0), Instance.argument_count);
    try std.testing.expectEqual(&receiver, Instance.receiver.?);
}

test "helpers2.resolveFromShape: extracts parameter types, return type and calling convention" {
    const Shape = fn (i32, ?*const u8) callconv(.c) ?*const u8;
    const resolved = resolveFromShape(Shape);
    try std.testing.expect(resolved.types.len == 2);
    try std.testing.expect(resolved.types[0] == i32);
    try std.testing.expect(resolved.types[1] == ?*const u8);
    try std.testing.expect(resolved.Return == ?*const u8);
    try std.testing.expect(std.meta.eql(resolved.cc, std.lang.CallingConvention.c));
}
