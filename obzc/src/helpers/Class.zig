const std = @import("std");
const obzc = @import("../root.zig");
const m = @import("method.zig");

/// Class helpers for a wrapper whose type or type factory is named after its Objective-C class.
pub fn Class(comptime T: type) type {
    const class_name = comptime obzc.utils.resolveTypeName(@typeName(T));

    return struct {
        /// Sends `alloc` to the class, returning an uninitialized instance to be sent an `init...` message.
        pub const alloc = method("alloc", fn () *T);

        /// Sends `new` to the class, returning a newly allocated and initialized instance.
        pub const new = method("new", fn () *T);

        /// Returns the Objective-C class bound to the wrapper type.
        pub fn getClass() *obzc.rt.Class {
            return obzc.rt.getClass(class_name).?;
        }

        /// Sends the selector named `sel` to the class itself (a class method).
        pub fn msgSend(comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            return obzc.rt.msgSend(getClass(), Return, obzc.rt.Sel.registerName(sel), args);
        }

        /// Sends a class message directly, preserving the declared return type.
        pub fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            return msgSend(Return, name, args);
        }

        /// Binds a class method to the signature `Shape`, accepting its arguments directly.
        /// Supports up to thirteen method arguments through `utils.spreadArgs`.
        pub fn method(
            comptime name: [:0]const u8,
            comptime Shape: type,
        ) *const Shape {
            return m.method(name, Shape, msgSend);
        }

        /// Binds a void class method whose last Shape parameter is a block function type.
        /// The returned function takes context, the preceding arguments, then a comptime handler.
        /// Captured context must outlive every invocation of the block handler.
        pub fn methodWithCallback(
            comptime name: [:0]const u8,
            comptime Shape: type,
        ) @TypeOf(m.methodWithCallback(name, Shape, msgSend).call) {
            return m.methodWithCallback(name, Shape, msgSend).call;
        }

        /// Waits for a one-shot completion; Shape returns an error union with void or an object pointer.
        /// Returned objects are retained. The completion must not require the blocked calling thread.
        pub fn methodSync(comptime name: [:0]const u8, comptime Shape: type) *const Shape {
            return m.methodSync(name, Shape, msgSend);
        }
    };
}

test "helpers.Class: call forwards class arguments and preserves nullable returns" {
    const NSNumber = opaque {};
    const NSObject = opaque {};
    const pool = obzc.rt.autoreleasePoolPush();
    defer obzc.rt.autoreleasePoolPop(pool);

    const number = Class(NSNumber).call(*NSNumber, "numberWithInteger:", .{@as(isize, 42)});
    try std.testing.expectEqual(42, obzc.helpers.Object(NSNumber).msgSend(number, isize, "integerValue", .{}));
    try std.testing.expectEqual(null, Class(NSObject).call(?*obzc.rt.Class, "superclass", .{}));
}

test "helpers.Class: class messages, new and alloc" {
    const NSMutableData = opaque {};
    const h = Class(NSMutableData);
    const rt = obzc.rt;
    const length = rt.Sel.registerName("length");
    const set_length = rt.Sel.registerName("setLength:");

    try std.testing.expectEqual(rt.getClass("NSMutableData").?, h.msgSend(*rt.Class, "class", .{}));

    const created = h.new();
    defer rt.release(@ptrCast(created));
    rt.msgSend(created, void, set_length, .{@as(usize, 5)});
    try std.testing.expectEqual(5, rt.msgSend(created, usize, length, .{}));

    const allocated = h.alloc();
    const initialized = rt.msgSend(allocated, ?*NSMutableData, rt.Sel.registerName("init"), .{}).?;
    defer rt.release(@ptrCast(initialized));
    rt.msgSend(initialized, void, set_length, .{@as(usize, 9)});
    try std.testing.expectEqual(9, rt.msgSend(initialized, usize, length, .{}));
}

test "helpers.Class: methodWithCallback sends a block and forwards its result" {
    const rt = obzc.rt;
    const ZigHelpersBlockMethodTest = opaque {};
    const State = struct { value: i32, calls: usize = 0 };
    const Completion = obzc.Block(*State, fn (i32, f64) i32);
    const Methods = struct {
        var result: i32 = 0;

        fn perform(_: *rt.Class, _: *rt.Sel, completion: *const Completion) callconv(.c) void {
            result = completion.invoke(completion, 3, 2.0);
        }

        fn performWithArgs(_: *rt.Class, _: *rt.Sel, value: i32, scale: f64, completion: *const Completion) callconv(.c) void {
            result = completion.invoke(completion, value, scale);
        }

        fn complete(state: *State, value: i32, scale: f64) i32 {
            state.calls += 1;
            return @intFromFloat(@as(f64, @floatFromInt(state.value + value)) * scale);
        }
    };
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ZigHelpersBlockMethodTest", 0).?;
    rt.registerClassPair(class);
    defer rt.disposeClassPair(class);
    const metaclass = rt.getMetaClass("ZigHelpersBlockMethodTest").?;
    try std.testing.expect(metaclass.addMethod(rt.Sel.registerName("performWithCompletion:"), &Methods.perform, "v@:@?"));
    try std.testing.expect(metaclass.addMethod(rt.Sel.registerName("performWithValue:scale:completion:"), &Methods.performWithArgs, "v@:id@?"));

    const perform = Class(ZigHelpersBlockMethodTest).methodWithCallback("performWithCompletion:", fn (fn (i32, f64) i32) void);
    var state: State = .{ .value = 7 };
    perform(&state, Methods.complete);
    try std.testing.expectEqual(1, state.calls);
    try std.testing.expectEqual(20, Methods.result);

    const perform_with_args = Class(ZigHelpersBlockMethodTest).methodWithCallback("performWithValue:scale:completion:", fn (i32, f64, fn (i32, f64) i32) void);
    perform_with_args(&state, 5, 2.5, Methods.complete);
    try std.testing.expectEqual(2, state.calls);
    try std.testing.expectEqual(30, Methods.result);
}

test "helpers.Class: methodSync binds a completion method" {
    const rt = obzc.rt;
    const ZigHelpersClassSyncTest = opaque {};
    const State = struct {};
    const Completion = obzc.Block(*State, fn (?*rt.Object) void);
    const Methods = struct {
        var received: i32 = 0;

        fn perform(_: *rt.Class, _: *rt.Sel, value: i32, completion: *const Completion) callconv(.c) void {
            received = value;
            completion.invoke(completion, null);
        }
    };
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ZigHelpersClassSyncTest", 0).?;
    rt.registerClassPair(class);
    defer rt.disposeClassPair(class);
    const metaclass = rt.getMetaClass("ZigHelpersClassSyncTest").?;
    try std.testing.expect(metaclass.addMethod(rt.Sel.registerName("perform:completion:"), &Methods.perform, "v@:i@?"));
    const perform = Class(ZigHelpersClassSyncTest).methodSync("perform:completion:", fn (i32) anyerror!void);
    try perform(42);
    try std.testing.expectEqual(42, Methods.received);
}

test "helpers.Class: method forwards typed arguments and returns an object" {
    const rt = obzc.rt;
    const pool = rt.autoreleasePoolPush();
    defer rt.autoreleasePoolPop(pool);
    const NSMutableData = opaque {};
    const create = Class(NSMutableData).method("dataWithLength:", fn (usize) *rt.Object);
    try std.testing.expect(@TypeOf(create) == *const fn (usize) *rt.Object);
    const data = create(7);
    try std.testing.expectEqual(7, rt.msgSend(data, usize, rt.Sel.registerName("length"), .{}));
    const get_class = Class(NSMutableData).method("class", fn () *rt.Class);
    try std.testing.expectEqual(rt.getClass("NSMutableData").?, get_class());
}
