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

        pub const method = if (has_receiver) method1 else method0;
        const method0 = createMethodHelper(call).method;
        fn method1(comptime name: [:0]const u8, comptime Shape: type) prependArgs(Shape, &.{*T}) {
            return method0(name, prependArgs(Shape, &.{*T}));
        }

        /// Binds a void message whose last Shape parameter is a block function type.
        /// Takes context, ordinary arguments, then a comptime handler, preceded by `*T` for instance methods.
        /// The context must outlive every invocation of the block handler.
        pub fn methodWithCallback(
            comptime name: [:0]const u8,
            comptime Shape: type,
        ) @TypeOf(MethodWithCallback(name, Shape).call) {
            return MethodWithCallback(name, Shape).call;
        }

        fn MethodWithCallback(comptime name: [:0]const u8, comptime Shape: type) type {
            const shape_info = switch (@typeInfo(Shape)) {
                .@"fn" => |info| info,
                else => @compileError("methodWithCallback Shape must be a function type"),
            };
            if (shape_info.attrs.varargs)
                @compileError("methodWithCallback Shape cannot have C variadic parameters");
            if (shape_info.return_type != void)
                @compileError("methodWithCallback Shape must return void");
            if (shape_info.param_types.len == 0)
                @compileError("methodWithCallback Shape must end with a block function type");

            const last = shape_info.param_types.len - 1;
            const Function = shape_info.param_types[last] orelse
                @compileError("methodWithCallback Shape must end with a known block function type");
            if (@typeInfo(Function) != .@"fn")
                @compileError("methodWithCallback Shape must end with a block function type");
            const fn_info = @typeInfo(Function).@"fn";
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("methodWithCallback requires fixed, non-generic block parameters");

            const MethodArgs = blk: {
                var params: [last]type = undefined;
                for (shape_info.param_types[0..last], 0..) |Param, i| params[i] = Param orelse
                    @compileError("methodWithCallback Shape parameters must have explicit types");
                break :blk @Tuple(&params);
            };

            return struct {
                pub const Args = MethodArgs;
                pub const call = if (has_receiver)
                    utils.spreadArgsWithReceiverAndCallback(*T, Args, Callback, invokeInstance)
                else
                    utils.spreadArgsWithCallback(Args, Callback, invoke);

                fn invokeInstance(self: *T, ctx: anytype, args: Args, comptime handler: *const Callback(@TypeOf(ctx))) void {
                    invoke(ctx, .{self} ++ args, handler);
                }

                fn invoke(ctx: anytype, args: anytype, comptime handler: *const Callback(@TypeOf(ctx))) void {
                    const blk = block.initWithContext(ctx, handler.*);
                    Self.call(void, name, args ++ .{&blk});
                }

                pub fn Callback(comptime Context: type) type {
                    var params: [fn_info.param_types.len + 1]type = undefined;
                    params[0] = Context;
                    for (fn_info.param_types, 1..) |Param, i| params[i] = Param.?;
                    return @Fn(&params, &@splat(.{}), fn_info.return_type.?, .{});
                }
            };
        }

        /// Waits for a one-shot completion using a dispatch semaphore.
        /// Prepends `*T` for instance methods. Shape returns an error union with void or an object pointer.
        /// Completion receives `(error)` or `(object, error)`; errors become `error.ObjectiveCError`.
        /// Returned objects are retained and must be released by the caller.
        /// The completion must be able to run while the calling thread is blocked.
        pub fn methodSync(
            comptime name: [:0]const u8,
            comptime Shape: type,
        ) if (has_receiver) prependArgs(Shape, &.{*T}) else Shape {
            const Signature = if (has_receiver) prependArgs(Shape, &.{*T}) else Shape;
            const fn_info = switch (@typeInfo(Signature)) {
                .@"fn" => |info| info,
                else => @compileError("methodSync Shape must be a function type"),
            };
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("methodSync Shape must have fixed, non-generic parameters");
            const Return = fn_info.return_type.?;
            const Payload = switch (@typeInfo(Return)) {
                .error_union => |info| info.payload,
                else => @compileError("methodSync Shape must return an error union"),
            };
            if (Payload != void) {
                if (@typeInfo(Payload) != .pointer)
                    @compileError("methodSync result must be void or an Objective-C object pointer");
                const pointer = @typeInfo(Payload).pointer;
                if (pointer.size != .one or pointer.attrs.@"allowzero" or @typeInfo(pointer.child) != .@"opaque")
                    @compileError("methodSync result must be a non-null pointer to an opaque Objective-C object");
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

            return utils.spreadArgs(Static.call, fn_info.attrs.@"callconv").*;
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

fn createMethodHelper(comptime call: anytype) type {
    return struct {
        pub fn method(comptime name: [:0]const u8, comptime Shape: type) Shape {
            const fn_info = switch (@typeInfo(Shape)) {
                .@"fn" => |info| info,
                else => @compileError("method Shape must be a function type"),
            };
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("method Shape must have fixed, non-generic parameters");

            const Return = fn_info.return_type.?;
            const Static = struct {
                fn invoke(args: std.meta.ArgsTuple(Shape)) Return {
                    return call(Return, name, args);
                }
            };

            return utils.spreadArgs(Static.invoke, fn_info.attrs.@"callconv").*;
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

test "methodSync: void completion and Objective-C errors" {
    const Helper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[1];
            completion.invoke(completion, args[0]);
        }
    };
    const m = Method(rt.Object, Helper);
    const bound = m.methodSync("complete:", fn (?*rt.Object) anyerror!void);
    try bound(null);
    const object = rt.msgSend(rt.getClass("NSObject").?, *rt.Object, rt.Sel.registerName("new"), .{});
    defer rt.release(object);
    try std.testing.expectError(error.ObjectiveCError, bound(object));
}

test "methodSync: asynchronous completion retains only successful results" {
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
    const bound = m.methodSync("complete:", fn (bool) anyerror!*rt.Object);
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

test "method: non-null pointer returns are preserved" {
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
        const bound = m.method("pointer", Shape);
        try std.testing.expectEqual(pointer, bound(pointer));
    }
}

test "method: nullable, zero-allowing and scalar returns are preserved" {
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
        const bound = m.method("value", fn (T) T);
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
