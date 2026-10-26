const std = @import("std");
const utils = @import("../../utils/root.zig");
const initBlockWithContext = @import("initBlockWithContext.zig").initBlockWithContext;

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
            const blk = initBlockWithContext(ctx, cb.*);
            return call(Resolved.Return, name, args ++ .{&blk});
        }

        fn invokeWithReceiver(
            receiver: Receiver.?,
            ctx: anytype,
            args: Args,
            comptime cb: *const Resolved.Callback(@TypeOf(ctx)),
        ) Resolved.Return {
            const blk = initBlockWithContext(ctx, cb.*);
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

test "helpers.makeWithCallback: appends a block bound to context and preserves the method result" {
    const State = struct {};
    const Receiver = struct {};
    const Handler = struct {
        fn complete(_: *State, _: i32) void {}
    };
    const Static = struct {
        var context: ?*State = null;
        var selector: []const u8 = "";
        var value: i32 = 0;
        fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            selector = name;
            value = args[0];
            context = args[1].context;
            return 17;
        }
    };
    const Instance = struct {
        var receiver: ?*Receiver = null;
        var context: ?*State = null;
        var selector: []const u8 = "";
        var value: i32 = 0;
        fn call(self: *Receiver, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            receiver = self;
            selector = name;
            value = args[0];
            context = args[1].context;
            return 31;
        }
    };
    const Shape = fn (i32, fn (i32) void) usize;
    const static = makeWithCallback(null, Static.call, "static:completion:", Shape).function;
    const instance = makeWithCallback(*Receiver, Instance.call, "instance:completion:", Shape).function;
    var state: State = .{};
    var receiver: Receiver = .{};
    try std.testing.expectEqual(@as(usize, 17), static(&state, -4, &Handler.complete));
    try std.testing.expectEqualStrings("static:completion:", Static.selector);
    try std.testing.expectEqual(@as(i32, -4), Static.value);
    try std.testing.expectEqual(&state, Static.context.?);
    try std.testing.expectEqual(@as(usize, 31), instance(&receiver, &state, 9, &Handler.complete));
    try std.testing.expectEqualStrings("instance:completion:", Instance.selector);
    try std.testing.expectEqual(@as(i32, 9), Instance.value);
    try std.testing.expectEqual(&receiver, Instance.receiver.?);
    try std.testing.expectEqual(&state, Instance.context.?);
}

test "helpers.makeWithCallback.resolveFromShape: separates method parameters and builds a context callback" {
    const State = struct {};
    const resolved = resolveFromShape(fn (u32, fn (i32, f64) bool) usize);
    try std.testing.expect(resolved.types.len == 1);
    try std.testing.expect(resolved.types[0] == u32);
    try std.testing.expect(resolved.Return == usize);
    try std.testing.expect(resolved.Callback(*State) == fn (*State, i32, f64) bool);
    const empty = resolveFromShape(fn (fn () void) void);
    try std.testing.expect(empty.types.len == 0);
    try std.testing.expect(empty.Callback(*State) == fn (*State) void);
}
