const std = @import("std");
const utils = @import("utils.zig");
const toSpreadedFn = @import("../../src/utils/root.zig").toSpreadedFn;
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

test "withCallback forwards selector, context and method return for class and instance" {
    const Method = @import("root.zig").Method;
    const State = struct { value: c_ulong = 0, calls: usize = 0 };
    const Receiver = struct { base: c_ulong };
    const ClassHelper = struct {
        var last_name: []const u8 = "";

        pub fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            if (Return != c_ulong) @compileError("unexpected method return type");
            last_name = name;
            const completion = args[1];
            completion.invoke(completion, args[0]);
            return args[0] + 100;
        }
    };
    const ObjectHelper = struct {
        var last_name: []const u8 = "";

        pub fn call(self: *Receiver, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            if (Return != c_ulong) @compileError("unexpected method return type");
            last_name = name;
            const completion = args[1];
            completion.invoke(completion, self.base + args[0]);
            return self.base + args[0] + 100;
        }
    };
    const Completion = struct {
        fn call(state: *State, value: c_ulong) void {
            state.value = value;
            state.calls += 1;
        }
    };
    const Shape = fn (c_ulong, fn (c_ulong) void) c_ulong;
    const class_method = Method(Receiver, ClassHelper).withCallback("value:completion:", Shape);
    const object_method = Method(Receiver, ObjectHelper).withCallback("value:completion:", Shape);
    const value: c_int = 4;
    var state: State = .{};
    try std.testing.expectEqual(@as(c_ulong, 104), class_method(&state, value, &Completion.call));
    try std.testing.expectEqualStrings("value:completion:", ClassHelper.last_name);
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(@as(c_ulong, 4), state.value);
    var receiver: Receiver = .{ .base = 10 };
    try std.testing.expectEqual(@as(c_ulong, 114), object_method(&receiver, &state, value, &Completion.call));
    try std.testing.expectEqualStrings("value:completion:", ObjectHelper.last_name);
    try std.testing.expectEqual(@as(usize, 2), state.calls);
    try std.testing.expectEqual(@as(c_ulong, 14), state.value);
}
