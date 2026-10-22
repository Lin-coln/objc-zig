const std = @import("std");
const utils = @import("utils.zig");
const rt = @import("../../rt/root.zig");

pub fn Method(comptime T: type, comptime Helper: type) type {
    const Receiver: ?type = utils.resolveReceiverType(T, Helper.call);

    return struct {
        pub fn of(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeMethod(name, Shape).function) {
            return makeMethod(name, Shape).function;
        }
        inline fn makeMethod(comptime name: [:0]const u8, comptime Shape: type) type {
            return @import("makeMethod.zig").makeMethod(Receiver, Helper.call, name, Shape);
        }

        pub fn withCallback(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeWithCallback(name, Shape).function) {
            return makeWithCallback(name, Shape).function;
        }
        inline fn makeWithCallback(comptime name: [:0]const u8, comptime Shape: type) type {
            return @import("makeWithCallback.zig").makeWithCallback(Receiver, Helper.call, name, Shape);
        }

        pub fn withSync(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(makeWithSync(name, Shape).function) {
            return makeWithSync(name, Shape).function;
        }
        inline fn makeWithSync(comptime name: [:0]const u8, comptime Shape: type) type {
            return @import("makeWithSync.zig").makeWithSync(Receiver, Helper.call, name, Shape);
        }
    };
}

test "withSync: void completion and Objective-C errors" {
    const Helper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[1];
            completion.invoke(completion, args[0]);
        }
    };
    const m = Method(rt.Object, Helper);
    const bound = m.withSync("complete:", fn (?*rt.Object) anyerror!void);
    try bound(null);
    const object = rt.msgSend(rt.getClass("NSObject").?, *rt.Object, rt.Sel.registerName("new"), .{});
    defer rt.release(object);
    try std.testing.expectError(error.ObjectiveCError, bound(object));
}

test "withSync: asynchronous completion retains only successful results" {
    const Methods = struct {
        var deallocations: usize = 0;

        fn dealloc(self: *rt.Object, _: *rt.Sel) callconv(.c) void {
            deallocations += 1;
            rt.msgSendSuper(self, rt.getClass("NSObject").?, void, rt.Sel.registerName("dealloc"), .{});
        }
    };
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ZigMethodSyncResultTest", 0).?;
    defer rt.disposeClassPair(class);
    try std.testing.expect(class.addMethod(rt.Sel.registerName("dealloc"), &Methods.dealloc, "v@:"));
    rt.registerClassPair(class);

    const Helper = struct {
        var thread: ?std.Thread = null;

        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const copied = args[1].copy().?;
            const Worker = struct {
                fn run(completion: @TypeOf(copied), fail: bool) void {
                    defer completion.release();
                    const object = rt.msgSend(rt.getClass("ZigMethodSyncResultTest").?, *rt.Object, rt.Sel.registerName("new"), .{});
                    defer rt.release(object);
                    completion.invoke(completion, object, if (fail) object else null);
                }
            };
            thread = std.Thread.spawn(.{}, Worker.run, .{ copied, args[0] }) catch @panic("cannot start completion thread");
        }
    };
    const m = Method(rt.Object, Helper);
    const bound = m.withSync("complete:", fn (bool) anyerror!*rt.Object);
    const success = bound(false);
    if (Helper.thread) |thread| {
        thread.join();
        Helper.thread = null;
    }
    {
        const result = try success;
        defer rt.release(result);
        try std.testing.expectEqual(0, Methods.deallocations);
        try std.testing.expectEqual(class, result.getClass());
    }
    try std.testing.expectEqual(1, Methods.deallocations);

    const failure = bound(true);
    if (Helper.thread) |thread| {
        thread.join();
        Helper.thread = null;
    }
    try std.testing.expectError(error.ObjectiveCError, failure);
    try std.testing.expectEqual(2, Methods.deallocations);
}

test "of: Shape preserves parameter types and contextual initialization" {
    const Payload = extern struct { value: c_ulong = 3 };
    const Receiver = struct { base: c_ulong };
    const ClassHelper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            return args[0] + args[1].value;
        }
    };
    const ObjectHelper = struct {
        pub fn call(self: *Receiver, comptime Return: type, _: [:0]const u8, args: anytype) Return {
            return self.base + args[0] + args[1].value;
        }
    };
    const Shape = fn (c_ulong, Payload) c_ulong;
    const class_method = Method(Receiver, ClassHelper).of("value:payload:", Shape);
    const object_method = Method(Receiver, ObjectHelper).of("value:payload:", Shape);
    const CShape = fn (c_ulong, Payload) callconv(.c) c_ulong;
    const c_method = Method(Receiver, ClassHelper).of("value:payload:", CShape);
    try std.testing.expect(@TypeOf(class_method) == Shape);
    try std.testing.expect(@TypeOf(object_method) == fn (*Receiver, c_ulong, Payload) c_ulong);
    try std.testing.expect(@TypeOf(c_method) == CShape);

    const value: c_int = 4;
    try std.testing.expectEqual(@as(c_ulong, 7), class_method(value, .{}));
    try std.testing.expectEqual(@as(c_ulong, 9), class_method(value, .{ .value = 5 }));
    try std.testing.expectEqual(@as(c_ulong, 9), c_method(value, .{ .value = 5 }));
    var receiver: Receiver = .{ .base = 10 };
    try std.testing.expectEqual(@as(c_ulong, 17), object_method(&receiver, value, .{}));
    try std.testing.expectEqual(@as(c_ulong, 19), object_method(&receiver, value, .{ .value = 5 }));
}

test "withCallback: class and instance bindings preserve constant coercion" {
    const State = struct { value: c_ulong = 0 };
    const Receiver = struct { base: c_ulong };
    const ClassHelper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[1];
            completion.invoke(completion, args[0]);
        }
    };
    const ObjectHelper = struct {
        pub fn call(self: *Receiver, comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[1];
            completion.invoke(completion, self.base + args[0]);
        }
    };
    const Completion = struct {
        fn call(state: *State, value: c_ulong) void {
            state.value = value;
        }
    };
    const Shape = fn (c_ulong, fn (c_ulong) void) void;
    const class_method = Method(Receiver, ClassHelper).withCallback("value:completion:", Shape);
    const object_method = Method(Receiver, ObjectHelper).withCallback("value:completion:", Shape);
    const value: c_int = 4;
    var state: State = .{};
    class_method(&state, value, &Completion.call);
    try std.testing.expectEqual(@as(c_ulong, 4), state.value);
    var receiver: Receiver = .{ .base = 10 };
    object_method(&receiver, &state, value, &Completion.call);
    try std.testing.expectEqual(@as(c_ulong, 14), state.value);
}

test "of: return types and pointer nullability are preserved" {
    const Helper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            if (Return != @TypeOf(args[0])) @compileError("unexpected message return type");
            return args[0];
        }
    };
    var value: u8 = 42;
    const m = Method(rt.Object, Helper);
    const cases = .{
        @as(*u8, &value),
        @as(*const u8, &value),
        @as([*]u8, @ptrCast(&value)),
        @as([*:0]const u8, "hello"),
        @as(?*u8, null),
        @as([*c]u8, null),
        @as(*allowzero u8, @ptrFromInt(0)),
        @as(usize, 42),
        false,
    };
    inline for (cases) |expected| {
        const T = @TypeOf(expected);
        const Shape = fn (T) T;
        const bound = m.of("value", Shape);
        try std.testing.expect(@TypeOf(bound) == Shape);
        try std.testing.expectEqual(expected, bound(expected));
    }
}
