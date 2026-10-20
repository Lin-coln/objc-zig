const std = @import("std");
const block = @import("block.zig");
const utils = @import("../utils/root.zig");
const rt = @import("../rt/root.zig");
const dispatch = std.c.dispatch;

/// Binds method builders to a wrapper type and its message helpers.
/// A leading `*T` parameter on `Helper.call` identifies an instance receiver.
pub fn Method(comptime T: type, comptime Helper: anytype) type {
    const has_receiver = @typeInfo(@TypeOf(Helper.call)).@"fn".param_types[0] == *T;

    return struct {
        const Self = @This();
        const call = if (has_receiver) callWithReceiver(Helper).call else Helper.call;

        /// Binds a method to Shape, prepending `*T` for an instance receiver.
        /// Shape excludes the receiver; the returned function accepts separate arguments.
        pub const of = createMethodHelper(T, Helper).method;

        /// Binds a void method whose final Shape parameter is a block function type.
        /// Call with receiver (for instances), context, method arguments, then the handler.
        /// Captured context must outlive every invocation of the block handler.
        pub const withCallback = createCallbackHelper(T, Helper).withCallback;

        /// Waits for a one-shot completion using a dispatch semaphore.
        /// Prepends `*T` for instance methods. Shape returns an error union with void or an object pointer.
        /// Completion receives `(error)` or `(object, error)`; errors become `error.ObjectiveCError`.
        /// Returned objects are retained and must be released by the caller.
        /// The completion must be able to run while the calling thread is blocked.
        pub fn withSync(comptime name: [:0]const u8, comptime Shape: type) if (has_receiver) prependArgs(Shape, &.{*T}) else Shape {
            const Signature = if (has_receiver) prependArgs(Shape, &.{*T}) else Shape;
            const fn_info = switch (@typeInfo(Signature)) {
                .@"fn" => |info| info,
                else => @compileError("withSync Shape must be a function type"),
            };
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("withSync Shape must have fixed, non-generic parameters");
            const Return = fn_info.return_type.?;
            const Payload = switch (@typeInfo(Return)) {
                .error_union => |info| info.payload,
                else => @compileError("withSync Shape must return an error union"),
            };
            if (Payload != void) {
                if (@typeInfo(Payload) != .pointer)
                    @compileError("withSync result must be void or an Objective-C object pointer");
                const pointer = @typeInfo(Payload).pointer;
                if (pointer.size != .one or pointer.attrs.@"allowzero" or @typeInfo(pointer.child) != .@"opaque")
                    @compileError("withSync result must be a non-null pointer to an opaque Objective-C object");
            }

            const Static = struct {
                const State = struct {
                    semaphore: dispatch.semaphore_t,
                    result: Return = undefined,
                };

                fn call(args: std.meta.ArgsTuple(Signature)) Return {
                    const semaphore = dispatch.semaphore_create(0) orelse return error.SemaphoreCreationFailed;
                    defer dispatch.release(semaphore.as_object());
                    var state: State = .{ .semaphore = semaphore };
                    // Keep the semaphore alive until signal itself has returned on the callback thread.
                    dispatch.retain(semaphore.as_object());
                    const completion = block.initWithContext(&state, if (Payload == void) completeVoid else completeObject);
                    Self.call(void, name, args ++ .{&completion});
                    _ = dispatch.semaphore_wait(semaphore, .FOREVER);
                    return state.result;
                }

                fn completeVoid(state: *State, err: ?*rt.Object) void {
                    const semaphore = state.semaphore;
                    defer dispatch.release(semaphore.as_object());
                    state.result = if (err != null) error.ObjectiveCError else {};
                    _ = dispatch.semaphore_signal(semaphore);
                }

                fn completeObject(state: *State, value: ?Payload, err: ?*rt.Object) void {
                    const semaphore = state.semaphore;
                    defer dispatch.release(semaphore.as_object());
                    state.result = if (err != null) error.ObjectiveCError else blk: {
                        const object = value orelse {
                            std.log.err("Objective-C completion for {s} returned nil without an error", .{name});
                            @panic("Objective-C completion returned nil without an error");
                        };
                        break :blk @as(Payload, @ptrCast(rt.retain(@ptrCast(@constCast(object)))));
                    };
                    // Do not access state after signaling: the waiting call may already have returned.
                    _ = dispatch.semaphore_signal(semaphore);
                }
            };

            return utils.spreadArgs(Static.call, .{ .convention = fn_info.attrs.@"callconv" });
        }
    };
}

fn callWithReceiver(comptime Helper: type) type {
    return struct {
        pub fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            var rest_args: @Tuple(@typeInfo(@TypeOf(args)).@"struct".field_types[1..]) = undefined;
            inline for (0..rest_args.len) |i| rest_args[i] = args[i + 1];
            return Helper.call(args[0], Return, name, rest_args);
        }
    };
}

fn createMethodHelper(comptime T: type, comptime Helper: type) type {
    const has_receiver = @typeInfo(@TypeOf(Helper.call)).@"fn".param_types[0] == *T;
    const ofs_r: usize = if (has_receiver) 1 else 0;

    return struct {
        pub fn method(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(of(name, Shape).func) {
            return of(name, Shape).func;
        }

        fn of(comptime name: [:0]const u8, comptime Shape: type) type {
            const fn_info = switch (@typeInfo(Shape)) {
                .@"fn" => |info| info,
                else => @compileError("of Shape must be a function type"),
            };
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("of Shape must have fixed, non-generic parameters");

            const Return = fn_info.return_type.?;
            const Signature = if (has_receiver) prependArgs(Shape, &.{*T}) else Shape;

            return struct {
                pub const func: Signature = utils.spreadArgs(invoke, .{
                    .convention = fn_info.attrs.@"callconv",
                });

                fn invoke(args: std.meta.ArgsTuple(Signature)) Return {
                    var method_args: std.meta.ArgsTuple(Shape) = undefined;
                    inline for (0..method_args.len) |i| method_args[i] = args[ofs_r + i];

                    if (comptime has_receiver) {
                        return Helper.call(args[0], Return, name, method_args);
                    } else {
                        return Helper.call(Return, name, method_args);
                    }
                }
            };
        }
    };
}

fn createCallbackHelper(comptime T: type, comptime Helper: type) type {
    const has_receiver = @typeInfo(@TypeOf(Helper.call)).@"fn".param_types[0] == *T;
    const ofs_r: usize = if (has_receiver) 1 else 0;

    return struct {
        pub fn withCallback(comptime name: [:0]const u8, comptime Shape: type) @TypeOf(of(name, Shape).func) {
            return of(name, Shape).func;
        }

        fn of(comptime name: [:0]const u8, comptime Shape: type) type {
            const Resolved = resolveTypesFromCallbackShape(Shape);
            return struct {
                pub const func = utils.spreadArgs(invoke, .{
                    // fn(receiver, ctx, ...args_and_callback)
                    .arity = ofs_r + 1 + @typeInfo(Shape).@"fn".param_types.len,
                });

                fn invoke(args: anytype) void {
                    const ctx = args[ofs_r];
                    const handler: *const Resolved.Callback(@TypeOf(ctx)) = args[args.len - 1];
                    var method_args: Resolved.Args = undefined;
                    inline for (0..method_args.len) |i| method_args[i] = args[ofs_r + 1 + i];
                    const blk = block.initWithContext(ctx, handler.*);

                    if (comptime has_receiver) {
                        Helper.call(args[0], void, name, method_args ++ .{&blk});
                    } else {
                        Helper.call(void, name, method_args ++ .{&blk});
                    }
                }
            };
        }
    };
}

fn resolveTypesFromCallbackShape(comptime Shape: type) type {
    const shape_info = switch (@typeInfo(Shape)) {
        .@"fn" => |info| info,
        else => @compileError("withCallback Shape must be a function type"),
    };
    if (shape_info.attrs.varargs)
        @compileError("withCallback Shape cannot have C variadic parameters");
    if (shape_info.return_type != void)
        @compileError("withCallback Shape must return void");
    if (shape_info.param_types.len == 0)
        @compileError("withCallback Shape must end with a block function type");

    const last = shape_info.param_types.len - 1;
    const Function = shape_info.param_types[last] orelse
        @compileError("withCallback Shape must end with a known block function type");
    if (@typeInfo(Function) != .@"fn")
        @compileError("withCallback Shape must end with a block function type");
    const fn_info = @typeInfo(Function).@"fn";
    if (fn_info.is_generic or fn_info.attrs.varargs)
        @compileError("withCallback requires fixed, non-generic block parameters");

    const MethodArgs = blk: {
        var params: [last]type = undefined;
        for (shape_info.param_types[0..last], 0..) |Param, i| params[i] = Param orelse
            @compileError("withCallback Shape parameters must have explicit types");
        break :blk @Tuple(&params);
    };

    return struct {
        pub const Args = MethodArgs;
        pub fn Callback(comptime Context: type) type {
            var params: [fn_info.param_types.len + 1]type = undefined;
            params[0] = Context;
            for (fn_info.param_types, 1..) |Param, i| params[i] = Param.?;
            return @Fn(&params, &@splat(.{}), fn_info.return_type.?, .{});
        }
    };
}

/// Prepends argument types to a fixed function signature, preserving its return type and attributes.
fn prependArgs(comptime Shape: type, comptime Args: []const type) type {
    const fn_info = switch (@typeInfo(Shape)) {
        .@"fn" => |info| info,
        else => @compileError("prependArgs Shape must be a function type"),
    };
    if (fn_info.is_generic or fn_info.attrs.varargs)
        @compileError("prependArgs Shape must have fixed, non-generic parameters");

    var params: [Args.len + fn_info.param_types.len]type = undefined;
    @memcpy(params[0..Args.len], Args);
    for (fn_info.param_types, Args.len..) |Param, i| params[i] = Param.?;
    var attrs: [params.len]std.lang.Type.Fn.ParamAttributes = @splat(.{});
    @memcpy(attrs[Args.len..], fn_info.param_attrs);
    return @Fn(&params, &attrs, fn_info.return_type.?, fn_info.attrs);
}

test "call: class and instance messages" {
    const NSMutableData = opaque {};
    const Class = @import("Class.zig").Class;
    const Object = @import("Object.zig").Object;
    const class = Method(NSMutableData, Class(NSMutableData));
    const instance = Method(NSMutableData, Object(NSMutableData));

    const data = class.call(*NSMutableData, "new", .{});
    defer rt.release(@ptrCast(data));
    instance.call(void, "setLength:", .{ data, @as(usize, 7) });
    try std.testing.expectEqual(7, instance.call(usize, "length", .{data}));
    try std.testing.expectEqual(rt.getClass("NSMutableData").?, class.call(*rt.Class, "class", .{}));
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
    try std.testing.expect(class.addMethod(rt.Sel.registerName("dealloc"), &Methods.dealloc, "v@:"));
    rt.registerClassPair(class);
    defer rt.disposeClassPair(class);

    const Helper = struct {
        var thread: std.Thread = undefined;

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
    Methods.deallocations = 0;
    const result = try bound(false);
    Helper.thread.join();
    try std.testing.expectEqual(0, Methods.deallocations);
    try std.testing.expectEqual(class, result.getClass());
    rt.release(result);
    try std.testing.expectEqual(1, Methods.deallocations);

    try std.testing.expectError(error.ObjectiveCError, bound(true));
    Helper.thread.join();
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
    try std.testing.expect(@TypeOf(class_method) == Shape);
    try std.testing.expect(@TypeOf(object_method) == fn (*Receiver, c_ulong, Payload) c_ulong);

    const value: c_int = 4;
    try std.testing.expectEqual(@as(c_ulong, 7), class_method(value, .{}));
    try std.testing.expectEqual(@as(c_ulong, 9), class_method(value, .{ .value = 5 }));
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

test "of: non-null pointer returns are preserved" {
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
    };
    inline for (cases) |pointer| {
        const T = @TypeOf(pointer);
        const Shape = fn (T) T;
        const bound = m.of("pointer", Shape);
        try std.testing.expectEqual(pointer, bound(pointer));
    }
}

test "of: nullable, zero-allowing and scalar returns are preserved" {
    const Helper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            if (Return != @TypeOf(args[0])) @compileError("unexpected message return type");
            return args[0];
        }
    };
    const m = Method(rt.Object, Helper);
    const cases = .{
        @as(?*u8, null),
        @as([*c]u8, null),
        @as(*allowzero u8, @ptrFromInt(0)),
        @as(usize, 42),
        false,
    };
    inline for (cases) |value| {
        const T = @TypeOf(value);
        const bound = m.of("value", fn (T) T);
        try std.testing.expectEqual(value, bound(value));
    }
}

test "prependArgs: parameter order, return type and function attributes" {
    const Shape = fn (noalias *i32, f64) callconv(.c) usize;
    try std.testing.expect(prependArgs(Shape, &.{}) == Shape);
    const Prepended = prependArgs(Shape, &.{ *anyopaque, u8 });
    try std.testing.expect(Prepended == fn (*anyopaque, u8, noalias *i32, f64) callconv(.c) usize);
    try std.testing.expect(@typeInfo(Prepended).@"fn".param_attrs[2].@"noalias");
}
