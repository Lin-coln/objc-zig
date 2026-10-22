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
            err: ?*anyopaque, // NSError
        ) void {
            const semaphore = state.semaphore;
            defer dispatch.release(semaphore.as_object());
            state.result = if (err != null) error.ObjectiveCError else {};
            _ = dispatch.semaphore_signal(semaphore);
        }

        fn completeObject(
            state: *State,
            value: ?Resolved.Payload,
            err: ?*anyopaque, // NSError
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
