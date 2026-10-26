const std = @import("std");
const utils = @import("../../utils/root.zig");
const toSpreadedFn = @import("../../utils/root.zig").toSpreadedFn;
const initBlockWithContext = @import("initBlockWithContext.zig").initBlockWithContext;
const dispatch = std.c.dispatch;
const ffi = @import("../../ffi/root.zig");
const c = ffi.c;

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
            const completion = initBlockWithContext(
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
            err: ?*ffi.Object, // NSError
        ) void {
            const semaphore = state.semaphore;
            defer dispatch.release(semaphore.as_object());
            state.result = if (err != null) error.ObjectiveCError else {};
            _ = dispatch.semaphore_signal(semaphore);
        }

        fn completeObject(
            state: *State,
            value: ?*ffi.Object,
            err: ?*ffi.Object, // NSError
        ) void {
            const semaphore = state.semaphore;
            defer dispatch.release(semaphore.as_object());
            const result = if (err != null) error.ObjectiveCError else blk: {
                const object = value orelse {
                    std.log.err("Objective-C completion for {s} returned nil without an error", .{name});
                    @panic("Objective-C completion returned nil without an error");
                };

                break :blk @as(Resolved.Payload, @ptrCast(c.objc_retain(@ptrCast(object)).?));
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

test "helpers.makeWithSync: forwards class arguments and maps void completion errors" {
    const Helper = struct {
        var selector: []const u8 = "";
        var value: i32 = 0;
        var fail = false;
        fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            selector = name;
            value = args[0];
            const completion = args[1];
            const error_token: *ffi.Object = @ptrFromInt(1);
            completion.invoke(completion, if (fail) error_token else null);
        }
    };
    const function = makeWithSync(null, Helper.call, "run:completion:", fn (i32) anyerror!void).function;
    try function(-3);
    try std.testing.expectEqualStrings("run:completion:", Helper.selector);
    try std.testing.expectEqual(@as(i32, -3), Helper.value);
    Helper.fail = true;
    try std.testing.expectError(error.ObjectiveCError, function(8));
}

test "helpers.makeWithSync: extracts the receiver and retains successful object results" {
    const Receiver = struct {};
    const Result = opaque {};
    const Helper = struct {
        var receiver: ?*Receiver = null;
        var selector: []const u8 = "";
        var fail = false;
        var object: *ffi.Object = undefined;
        fn call(self: *Receiver, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            receiver = self;
            selector = name;
            const completion = args[0];
            completion.invoke(completion, if (fail) null else object, if (fail) object else null);
        }
    };
    const raw = c.class_createInstance(c.objc_getClass("NSObject").?, 0).?;
    defer c.objc_release(raw);
    Helper.object = @ptrCast(raw);
    const function = makeWithSync(*Receiver, Helper.call, "fetch:", fn () anyerror!*Result).function;
    var receiver: Receiver = .{};
    const result = try function(&receiver);
    defer c.objc_release(@ptrCast(result));
    try std.testing.expectEqual(@as(*Result, @ptrCast(raw)), result);
    try std.testing.expectEqual(&receiver, Helper.receiver.?);
    try std.testing.expectEqualStrings("fetch:", Helper.selector);
    Helper.fail = true;
    try std.testing.expectError(error.ObjectiveCError, function(&receiver));
}

test "helpers.makeWithSync: waits for completion on another thread" {
    const Helper = struct {
        var thread: ?std.Thread = null;
        fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            const completion = args[0].copy().?;
            const Worker = struct {
                fn run(copied: @TypeOf(completion)) void {
                    defer c._Block_release(copied);
                    copied.invoke(copied, null);
                }
            };
            thread = std.Thread.spawn(.{}, Worker.run, .{completion}) catch @panic("cannot start completion thread");
        }
    };
    const function = makeWithSync(null, Helper.call, "run:", fn () anyerror!void).function;
    const result = function();
    defer Helper.thread.?.join();
    try result;
}

test "helpers.makeWithSync.resolveFromShape: extracts the error union payload and method signature" {
    const Result = opaque {};
    const resolved = resolveFromShape(fn (i32) anyerror!*Result);
    try std.testing.expect(resolved.types.len == 1);
    try std.testing.expect(resolved.types[0] == i32);
    try std.testing.expect(resolved.Return == anyerror!*Result);
    try std.testing.expect(resolved.Payload == *Result);
    const empty = resolveFromShape(fn () anyerror!void);
    try std.testing.expect(empty.types.len == 0);
    try std.testing.expect(empty.Payload == void);
}
