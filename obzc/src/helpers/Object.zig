const std = @import("std");
const obzc = @import("../root.zig");
const Class = @import("Class.zig").Class;
const m = @import("method.zig");
const cast = obzc.utils.cast;

/// Returns a set of Objective-C object helpers bound to `T` (any opaque object type). Assemble a
/// wrapper by picking the pieces you want:
///
///     const h = obzc.helpers.Object(Self);
///     pub const release = h.release;
///     pub const width = h.prop(usize, "width").getter;
///
/// Class helpers such as `alloc`, `new`, and class `msgSend` are available through `h.cls`.
pub fn Object(comptime T: type) type {
    return struct {
        pub const cls = Class(T);

        pub fn retain(self: *T) *T {
            return @ptrCast(obzc.rt.retain(@ptrCast(self)));
        }

        pub fn release(self: *T) void {
            obzc.rt.release(@ptrCast(self));
        }

        /// Sends the selector named `sel` to the object.
        pub fn msgSend(self: *T, comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            return obzc.rt.msgSend(self, Return, obzc.rt.Sel.registerName(sel), args);
        }

        /// Sends an instance message directly, preserving the declared return type.
        pub fn call(self: *T, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            return msgSend(self, Return, name, args);
        }

        /// Binds an instance method, prepending `*T` to the declared Shape.
        pub fn method(comptime name: [:0]const u8, comptime Shape: type) m.prependArgs(Shape, &.{*T}) {
            return m.method(name, m.prependArgs(Shape, &.{*T}), sendMethod).*;
        }

        fn sendMethod(comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            var method_args: @Tuple(@typeInfo(@TypeOf(args)).@"struct".field_types[1..]) = undefined;
            inline for (0..method_args.len) |i| method_args[i] = args[i + 1];
            return msgSend(args[0], Return, sel, method_args);
        }

        /// Waits for a one-shot completion; Shape excludes self and returns an error union.
        /// Returned objects are retained. The completion must not require the blocked calling thread.
        pub fn methodSync(comptime name: [:0]const u8, comptime Shape: type) m.prependArgs(Shape, &.{*T}) {
            return m.methodSync(name, m.prependArgs(Shape, &.{*T}), sendMethod).*;
        }

        /// Binds a void instance method whose last Shape parameter is a block function type.
        /// Call as `object.method(ctx, args..., handler)`; Shape excludes the receiver.
        /// The context must outlive every invocation of the block handler.
        pub fn methodWithCallback(
            comptime name: [:0]const u8,
            comptime Shape: type,
        ) @TypeOf(MethodWithCallback(name, Shape).call) {
            return MethodWithCallback(name, Shape).call;
        }

        fn MethodWithCallback(comptime name: [:0]const u8, comptime Shape: type) type {
            return struct {
                const Binding = m.methodWithCallback(name, Shape, sendMethod);
                pub const call = obzc.utils.spreadArgsWithReceiverAndCallback(*T, Binding.Args, Binding.Callback, invoke);

                fn invoke(self: *T, ctx: anytype, args: Binding.Args, comptime handler: *const Binding.Callback(@TypeOf(ctx))) void {
                    Binding.invoke(ctx, .{self} ++ args, handler);
                }
            };
        }

        /// Reads the instance property `name` as `P`, using the class bound to `T` for metadata.
        /// Honors its `G` attribute, falling back to `name` itself as the getter selector.
        pub fn property(self: *T, comptime P: type, name: [:0]const u8) P {
            const getter = if (cls.getClass().getProperty(name)) |metadata| metadata.copyAttributeValue("G") else null;
            defer if (getter) |custom| std.c.free(custom.ptr);

            const selector = getter orelse name;
            if (P == bool) {
                return cast.bool(msgSend(self, obzc.c.BOOL, selector, .{}));
            } else {
                return msgSend(self, P, selector, .{});
            }
        }

        /// Writes `value` to the Objective-C property `name` via its `set<Name>:` setter.
        pub fn setProperty(self: *T, comptime name: [:0]const u8, value: anytype) void {
            const setter = "set" ++ [_]u8{std.ascii.toUpper(name[0])} ++ name[1..] ++ ":";
            if (@TypeOf(value) == bool) {
                msgSend(self, void, setter, .{cast.BOOL(value)});
            } else {
                msgSend(self, void, setter, .{value});
            }
        }

        /// Accessor methods for the property `name` of type `P`:
        ///
        ///     pub const width = h.prop(usize, "width").getter;
        ///     pub const setWidth = h.prop(usize, "width").setter;
        pub fn prop(comptime P: type, comptime name: [:0]const u8) type {
            return struct {
                pub fn getter(self: *T) P {
                    return property(self, P, name);
                }
                pub fn setter(self: *T, value: P) void {
                    setProperty(self, name, value);
                }
            };
        }
    };
}

test "helpers.Object: call forwards instance receivers and arguments" {
    const NSNumber = opaque {
        pub const call = Object(@This()).call;
    };
    const h = Object(NSNumber);
    const pool = obzc.rt.autoreleasePoolPush();
    defer obzc.rt.autoreleasePoolPop(pool);

    const first = h.cls.msgSend(*NSNumber, "numberWithInteger:", .{@as(isize, 7)});
    const second = h.cls.msgSend(*NSNumber, "numberWithInteger:", .{@as(isize, 12)});
    try std.testing.expectEqual(7, first.call(isize, "integerValue", .{}));
    try std.testing.expectEqual(12, second.call(isize, "integerValue", .{}));
    try std.testing.expectEqual(obzc.c.NO, first.call(obzc.c.BOOL, "isEqualToNumber:", .{second}));
    try std.testing.expectEqual(obzc.c.YES, first.call(obzc.c.BOOL, "isEqualToNumber:", .{first}));
    try std.testing.expectEqual(first, first.call(?*NSNumber, "self", .{}).?);
}

test "helpers.Object: method binds instance receivers and arguments" {
    const NSMutableData = opaque {
        const Self = @This();
        const h = Object(Self);

        pub const length = h.method("length", fn () usize);
        pub const setLength = h.method("setLength:", fn (usize) void);
    };
    const h = Object(NSMutableData);
    const first = h.cls.new();
    defer h.release(first);
    const second = h.cls.new();
    defer h.release(second);

    first.setLength(7);
    second.setLength(12);
    try std.testing.expectEqual(7, first.length());
    try std.testing.expectEqual(12, second.length());
}

test "helpers.Object: methodWithCallback forwards instance receivers and arguments" {
    const rt = obzc.rt;
    const ZigHelpersInstanceCallbackTest = opaque {
        const h = Object(@This());

        pub const perform = h.methodWithCallback("performWithCompletion:", fn (fn (*rt.Object, i32) i32) void);
        pub const performWithValue = h.methodWithCallback("performWithValue:completion:", fn (i32, fn (*rt.Object, i32) i32) void);
    };
    const State = struct { receiver: ?*rt.Object = null, calls: usize = 0, value: i32 = 7 };
    const Completion = obzc.Block(*State, fn (*rt.Object, i32) i32);
    const Methods = struct {
        var result: i32 = 0;

        fn perform(self: *rt.Object, _: *rt.Sel, completion: *const Completion) callconv(.c) void {
            result = completion.invoke(completion, self, 3);
        }

        fn performWithValue(self: *rt.Object, _: *rt.Sel, value: i32, completion: *const Completion) callconv(.c) void {
            result = completion.invoke(completion, self, value);
        }

        fn complete(state: *State, receiver: *rt.Object, value: i32) i32 {
            state.receiver = receiver;
            state.calls += 1;
            return state.value + value;
        }
    };
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ZigHelpersInstanceCallbackTest", 0).?;
    try std.testing.expect(class.addMethod(rt.Sel.registerName("performWithCompletion:"), &Methods.perform, "v@:@?"));
    try std.testing.expect(class.addMethod(rt.Sel.registerName("performWithValue:completion:"), &Methods.performWithValue, "v@:i@?"));
    rt.registerClassPair(class);
    defer rt.disposeClassPair(class);

    const h = Object(ZigHelpersInstanceCallbackTest);
    const first = h.cls.new();
    defer h.release(first);
    const second = h.cls.new();
    defer h.release(second);
    var state: State = .{};

    first.perform(&state, Methods.complete);
    try std.testing.expectEqual(@as(*rt.Object, @ptrCast(first)), state.receiver.?);
    try std.testing.expectEqual(1, state.calls);
    try std.testing.expectEqual(10, Methods.result);

    second.performWithValue(&state, 12, Methods.complete);
    try std.testing.expectEqual(@as(*rt.Object, @ptrCast(second)), state.receiver.?);
    try std.testing.expectEqual(2, state.calls);
    try std.testing.expectEqual(19, Methods.result);
}

test "helpers.Object: methodSync binds an instance receiver and returns a retained object" {
    const rt = obzc.rt;
    const ZigHelpersObjectSyncTest = opaque {
        const Self = @This();
        pub const perform = Object(Self).methodSync("perform:completion:", fn (i32) anyerror!*Self);
    };
    const State = struct {};
    const Completion = obzc.Block(*State, fn (?*ZigHelpersObjectSyncTest, ?*rt.Object) void);
    const Methods = struct {
        var received: i32 = 0;

        fn perform(self: *ZigHelpersObjectSyncTest, _: *rt.Sel, value: i32, completion: *const Completion) callconv(.c) void {
            received = value;
            completion.invoke(completion, self, null);
        }
    };
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ZigHelpersObjectSyncTest", 0).?;
    try std.testing.expect(class.addMethod(rt.Sel.registerName("perform:completion:"), &Methods.perform, "v@:i@?"));
    rt.registerClassPair(class);
    defer rt.disposeClassPair(class);
    const h = Object(ZigHelpersObjectSyncTest);
    const first = h.cls.new();
    defer h.release(first);
    const second = h.cls.new();
    defer h.release(second);

    const first_result = try first.perform(7);
    defer h.release(first_result);
    try std.testing.expectEqual(first, first_result);
    try std.testing.expectEqual(7, Methods.received);
    const second_result = try second.perform(12);
    defer h.release(second_result);
    try std.testing.expectEqual(second, second_result);
    try std.testing.expectEqual(12, Methods.received);
}

test "helpers.Object: property / setProperty" {
    const NSMutableData = opaque {};
    const h = Object(NSMutableData);
    const data = h.cls.new();
    defer h.release(data);

    h.setProperty(data, "length", @as(usize, 8));
    try std.testing.expectEqual(8, h.property(data, usize, "length"));
}

test "helpers.Object: prop getter and setter" {
    const NSMutableData = opaque {};
    const h = Object(NSMutableData);
    const length = h.prop(usize, "length");
    const data = h.cls.new();
    defer h.release(data);

    length.setter(data, 12);
    try std.testing.expectEqual(12, length.getter(data));
}

test "helpers.Object: property honors a custom getter" {
    const NSOperation = opaque {};
    const h = Object(NSOperation);
    const operation = h.cls.new();
    defer h.release(operation);

    const cancelled = h.cls.getClass().getProperty("cancelled").?;
    const getter = cancelled.copyAttributeValue("G").?;
    defer std.c.free(getter.ptr);
    try std.testing.expectEqualStrings("isCancelled", getter);

    try std.testing.expectEqual(false, h.property(operation, bool, "cancelled"));
    h.msgSend(operation, void, "cancel", .{});
    try std.testing.expectEqual(true, h.property(operation, bool, "cancelled"));
}
