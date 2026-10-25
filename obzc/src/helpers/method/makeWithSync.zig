const std = @import("std");
const utils = @import("utils.zig");
const toSpreadedFn = @import("../../utils/root.zig").toSpreadedFn;
const block = @import("../block.zig");
const dispatch = std.c.dispatch;
const rt = @import("../../rt/root.zig");

pub fn makeWithSync(
    comptime Receiver: ?type,
    comptime call: anytype,
    comptime name: [:0]const u8,
    comptime Shape: type,
) type {
    const Resolved = resolveFromShape(Shape);

    const Args = if (Receiver) |R| @Tuple(&([_]type{R} ++ Resolved.types)) else @Tuple(&Resolved.types);

    const State = struct {
        semaphore: dispatch.semaphore_t,
        result: Resolved.Return = undefined,
    };

    return struct {
        pub const function = toSpreadedFn(invoke, .{ .cc = Resolved.cc });
        fn invoke(args: Args) Resolved.Return {
            const semaphore = dispatch.semaphore_create(0) orelse return error.SemaphoreCreationFailed;
            defer dispatch.release(semaphore.as_object());
            var state: State = .{ .semaphore = semaphore };
            // Keep the semaphore alive until signal itself has returned on the callback thread.
            dispatch.retain(semaphore.as_object());
            const completion = block.initWithContext(
                &state,
                if (comptime Resolved.Payload == void)
                    completeVoid
                else
                    completeObject,
            );

            if (comptime Receiver != null) {
                const CallArgs = @Tuple(&Resolved.types);
                var call_args: CallArgs = undefined;
                inline for (0..Resolved.types.len) |i| {
                    call_args[i] = args[i + 1];
                }

                _ = call(args[0], void, name, call_args ++ .{&completion});
            } else {
                _ = call(void, name, args ++ .{&completion});
            }

            _ = dispatch.semaphore_wait(semaphore, .FOREVER);

            return state.result;
        }

        fn completeVoid(
            state: *State,
            err: ?*rt.Object, // NSError
        ) void {
            const semaphore = state.semaphore;
            defer dispatch.release(semaphore.as_object());
            state.result = if (err != null) error.ObjectiveCError else {};
            _ = dispatch.semaphore_signal(semaphore);
        }

        fn completeObject(
            state: *State,
            value: ?Resolved.Payload,
            err: ?*rt.Object, // NSError
        ) void {
            const semaphore = state.semaphore;
            defer dispatch.release(semaphore.as_object());
            const result = if (err != null) error.ObjectiveCError else blk: {
                const object = value orelse {
                    std.log.err("Objective-C completion for {s} returned nil without an error", .{name});
                    @panic("Objective-C completion returned nil without an error");
                };

                break :blk @as(
                    Resolved.Payload,
                    @ptrCast(
                        rt.retain(@ptrCast(@constCast(object))),
                    ),
                );
            };

            state.result = result;

            // Do not access state after signaling: the waiting call may already have returned.
            _ = dispatch.semaphore_signal(semaphore);
        }
    };
}

fn resolveFromShape(comptime Shape: type) type {
    const info = utils.resolveFnInfo(Shape, .{});

    const R = info.return_type.?;
    const P = blk: {
        const Type = switch (@typeInfo(R)) {
            .error_union => |x| x.payload,
            else => @compileError("withSync Shape must return an error union"),
        };
        if (Type == void) break :blk Type;
        switch (@typeInfo(Type)) {
            .pointer => |p| {
                if (p.size != .one or p.attrs.@"allowzero" or @typeInfo(p.child) != .@"opaque") {
                    @compileError("withSync result must be a non-null pointer to an opaque Objective-C object");
                }
            },
            else => @compileError("withSync result must be void or an Objective-C object pointer"),
        }
        break :blk Type;
    };

    // types
    comptime var param_types: [info.param_types.len]type = undefined;
    inline for (info.param_types, 0..) |p_type, i| {
        param_types[i] = p_type.?;
    }
    const resolved_types = param_types;

    return struct {
        pub const types = resolved_types;
        pub const cc = info.attrs.@"callconv";
        pub const Return = R;
        pub const Payload = P;
    };
}

test "withSync completion encodes NSError as an Objective-C object" {
    const VoidHelper = struct {
        var signature: []const u8 = "";

        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[0];
            signature = std.mem.span(completion.descriptor.signature);
            completion.invoke(completion, null);
        }
    };
    const complete_void = makeWithSync(null, VoidHelper.call, "complete:", fn () anyerror!void).function;
    try complete_void();
    try std.testing.expectEqualStrings("v@?@", VoidHelper.signature);

    const ObjectHelper = struct {
        var signature: []const u8 = "";

        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[0];
            signature = std.mem.span(completion.descriptor.signature);
            const err = rt.msgSend(rt.getClass("NSObject").?, *rt.Object, rt.Sel.registerName("new"), .{});
            defer rt.release(err);
            completion.invoke(completion, null, err);
        }
    };
    const complete_object = makeWithSync(null, ObjectHelper.call, "complete:", fn () anyerror!*rt.Object).function;
    try std.testing.expectError(error.ObjectiveCError, complete_object());
    try std.testing.expectEqualStrings("v@?@@", ObjectHelper.signature);
}

test "withSync: void completion and Objective-C errors" {
    const Method = @import("root.zig").Method;
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
    const Method = @import("root.zig").Method;
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
