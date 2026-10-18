const std = @import("std");
const block = @import("block.zig");
const utils = @import("../utils/root.zig");
const rt = @import("../rt/root.zig");
const dispatch = std.c.dispatch;

/// Prepends argument types to a fixed function signature, preserving its return type and attributes.
pub fn prependArgs(comptime Shape: type, comptime Args: []const type) type {
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

/// Binds a selector to `Shape` using the supplied message sender.
/// The sender receives `(Return, name, args)` and handles the target itself.
/// Non-null one/many pointer returns are received as optional pointers and unwrapped with `.?`.
pub fn method(
    comptime name: [:0]const u8,
    comptime Shape: type,
    comptime sender: anytype,
) *const Shape {
    const fn_info = switch (@typeInfo(Shape)) {
        .@"fn" => |info| info,
        else => @compileError("method Shape must be a function type"),
    };
    if (fn_info.is_generic or fn_info.attrs.varargs)
        @compileError("method Shape must have fixed, non-generic parameters");

    const Return = fn_info.return_type.?;
    const Static = struct {
        fn call(args: std.meta.ArgsTuple(Shape)) Return {
            switch (@typeInfo(Return)) {
                .pointer => |info| {
                    if ((info.size == .one or info.size == .many) and !info.attrs.@"allowzero")
                        return sender(?Return, name, args).?;
                },
                else => {},
            }

            return sender(Return, name, args);
        }
    };

    return utils.spreadArgs(Static.call, fn_info.attrs.@"callconv");
}

/// Binds a void message whose last Shape parameter is a block function type.
/// `call` takes context, ordinary arguments, then a comptime handler.
/// `invoke` also accepts a prefixed argument tuple for receiver adapters.
/// The context must outlive every invocation of the block handler.
pub fn methodWithCallback(
    comptime name: [:0]const u8,
    comptime Shape: type,
    comptime sender: anytype,
) type {
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
        pub const call = utils.spreadArgsWithCallback(Args, Callback, invoke);

        pub fn invoke(ctx: anytype, args: anytype, comptime handler: *const Callback(@TypeOf(ctx))) void {
            const blk = block.initWithContext(ctx, handler.*);
            sender(void, name, args ++ .{&blk});
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
/// Shape returns an error union with void or a non-null Objective-C object pointer.
/// Completion receives `(error)` or `(object, error)`; errors become `error.ObjectiveCError`.
/// Returned objects are retained and must be released by the caller.
/// The completion must be able to run while the calling thread is blocked.
pub fn methodSync(
    comptime name: [:0]const u8,
    comptime Shape: type,
    comptime sender: anytype,
) *const Shape {
    const fn_info = switch (@typeInfo(Shape)) {
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

        fn call(args: std.meta.ArgsTuple(Shape)) Return {
            const semaphore = dispatch.semaphore_create(0) orelse return error.SemaphoreCreationFailed;
            defer dispatch.release(semaphore.as_object());
            var state: State = .{ .semaphore = semaphore };
            // Keep the semaphore alive until signal itself has returned on the callback thread.
            dispatch.retain(semaphore.as_object());
            const completion = block.initWithContext(&state, if (Payload == void) completeVoid else completeObject);
            sender(void, name, args ++ .{&completion});
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

    return utils.spreadArgs(Static.call, fn_info.attrs.@"callconv");
}

test "methodSync: void completion and Objective-C errors" {
    const Sender = struct {
        fn send(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[1];
            completion.invoke(completion, args[0]);
        }
    };
    const bound = methodSync("complete:", fn (?*rt.Object) anyerror!void, Sender.send);
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

    const Sender = struct {
        var thread: std.Thread = undefined;

        fn send(comptime Return: type, _: [:0]const u8, args: anytype) Return {
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
    const bound = methodSync("complete:", fn (bool) anyerror!*rt.Object, Sender.send);
    Methods.deallocations = 0;
    const result = try bound(false);
    Sender.thread.join();
    try std.testing.expectEqual(0, Methods.deallocations);
    try std.testing.expectEqual(class, result.getClass());
    rt.release(result);
    try std.testing.expectEqual(1, Methods.deallocations);

    try std.testing.expectError(error.ObjectiveCError, bound(true));
    Sender.thread.join();
    try std.testing.expectEqual(2, Methods.deallocations);
}

test "method: non-null pointers use nullable message returns" {
    const Sender = struct {
        fn send(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            if (Return != @TypeOf(args[0])) @compileError("unexpected message return type");
            return args[0];
        }
    };
    var value: u8 = 42;
    const cases = .{
        .{ *u8, @as(?*u8, &value) },
        .{ *const u8, @as(?*const u8, &value) },
        .{ [*]u8, @as(?[*]u8, @ptrCast(&value)) },
        .{ [*:0]const u8, @as(?[*:0]const u8, "hello") },
    };
    inline for (cases) |case| {
        const Shape = fn (@TypeOf(case[1])) case[0];
        const bound = method("pointer", Shape, Sender.send);
        try std.testing.expectEqual(case[1].?, bound(case[1]));
    }
}

test "method: nullable, zero-allowing and scalar returns are preserved" {
    const Sender = struct {
        fn send(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            if (Return != @TypeOf(args[0])) @compileError("unexpected message return type");
            return args[0];
        }
    };
    const cases = .{
        @as(?*u8, null),
        @as([*c]u8, null),
        @as(*allowzero u8, @ptrFromInt(0)),
        @as(usize, 42),
        false,
    };
    inline for (cases) |value| {
        const T = @TypeOf(value);
        const bound = method("value", fn (T) T, Sender.send);
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
