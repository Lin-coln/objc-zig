const std = @import("std");
const utils = @import("utils.zig");
const toSpreadedFn = @import("../../utils/root.zig").toSpreadedFn;
const block = @import("../block.zig");

pub fn makeWithCallback(
    comptime Receiver: ?type,
    comptime call: anytype,
    comptime name: [:0]const u8,
    comptime Shape: type,
) type {
    const Resolved = resolveFromShape(Shape);
    const Args = @Tuple(&Resolved.types);

    return struct {
        pub const function = @import("spreadForCallback.zig").toSpreadFn(
            if (Receiver == null) invoke else invokeWithReceiver,
            .{ .cc = .auto },
            Resolved.Callback,
        );

        fn invoke(
            ctx: anytype,
            args: Args,
            comptime cb: *const Resolved.Callback(@TypeOf(ctx)),
        ) Resolved.Return {
            const blk = block.initWithContext(ctx, cb.*);
            return call(Resolved.Return, name, args ++ .{&blk});
        }

        fn invokeWithReceiver(
            receiver: Receiver.?,
            ctx: anytype,
            args: Args,
            comptime cb: *const Resolved.Callback(@TypeOf(ctx)),
        ) Resolved.Return {
            const blk = block.initWithContext(ctx, cb.*);
            return call(receiver, Resolved.Return, name, args ++ .{&blk});
        }
    };
}

fn resolveFromShape(comptime Shape: type) type {
    const info = utils.resolveFnInfo(Shape, .{
        .generic = true,
    });

    // if (info.return_type != void)
    //     @compileError("withCallback Shape must return void");

    const info_fn: std.lang.Type.Fn = blk: {
        if (info.param_types.len == 0)
            @compileError("Shape must end with a block function type");
        const FunctionShape = info.param_types[info.param_types.len - 1] orelse
            @compileError("Shape must end with a known block function type");
        break :blk utils.resolveFnInfo(FunctionShape, .{});
    };

    // types
    comptime var param_types: [info.param_types.len - 1]type = undefined;
    inline for (info.param_types[0 .. info.param_types.len - 1], 0..) |p_type, i| {
        param_types[i] = p_type.?;
    }
    const resolved_types = param_types;

    return struct {
        pub const types = resolved_types;
        pub const cc = info.attrs.@"callconv";

        pub const Return = info.return_type.?;

        pub fn Callback(comptime Context: type) type {
            comptime var cb_params_types: [info_fn.param_types.len + 1]type = undefined;
            cb_params_types[0] = Context;
            inline for (info_fn.param_types, 1..) |p_type, i| {
                cb_params_types[i] = p_type.?;
            }
            return @Fn(&cb_params_types, &@splat(.{}), info_fn.return_type.?, .{});
        }
    };
}

test "withCallback: class and instance bindings forward zero through fifteen method arguments" {
    @setEvalBranchQuota(100_000);
    const State = struct { result: i32 = 0 };
    const Receiver = struct { base: i32 };
    const ClassHelper = struct {
        pub fn call(comptime Return: type, _: [:0]const u8, args: anytype) Return {
            var result: i32 = 0;
            inline for (0..args.len - 1) |i| {
                result += args[i] * @as(i32, @intCast(i + 1));
            }
            const completion = args[args.len - 1];
            completion.invoke(completion, result);
        }
    };
    const ObjectHelper = struct {
        pub fn call(self: *Receiver, comptime Return: type, _: [:0]const u8, args: anytype) Return {
            var result = self.base;
            inline for (0..args.len - 1) |i| {
                result += args[i] * @as(i32, @intCast(i + 1));
            }
            const completion = args[args.len - 1];
            completion.invoke(completion, result);
        }
    };
    const Completion = struct {
        fn call(state: *State, result: i32) void {
            state.result = result;
        }
    };

    inline for (0..16) |count| {
        comptime var params: [count + 1]type = undefined;
        inline for (0..count) |i| params[i] = i32;
        params[count] = fn (i32) void;
        const Shape = @Fn(&params, &@splat(.{}), void, .{});
        const class_method = makeWithCallback(null, ClassHelper.call, "complete:", Shape).function;
        const object_method = makeWithCallback(*Receiver, ObjectHelper.call, "complete:", Shape).function;

        var args: @Tuple(&@as([count]type, @splat(i32))) = undefined;
        var expected: i32 = 0;
        inline for (0..count) |i| {
            const value: i32 = @intCast(i + 1);
            args[i] = value;
            expected += value * value;
        }

        var state: State = .{};
        @call(.auto, class_method, .{&state} ++ args ++ .{&Completion.call});
        try std.testing.expectEqual(expected, state.result);

        var receiver: Receiver = .{ .base = 100 };
        @call(.auto, object_method, .{ &receiver, &state } ++ args ++ .{&Completion.call});
        try std.testing.expectEqual(100 + expected, state.result);
    }
}
