const std = @import("std");
const obzc = @import("../root.zig");

/// Creates a stack block for a handler receiving `ctx` and zero to twelve block arguments.
/// The context pointer must outlive every invocation, including heap copies.
pub fn initWithContext(
    ctx: anytype,
    comptime handler: anytype,
) BlockFromContextHandler(@TypeOf(ctx), @typeInfo(@TypeOf(handler)).@"fn") {
    const Context = @TypeOf(ctx);
    const Handler = @TypeOf(handler);
    if (@typeInfo(Context) != .pointer or @typeInfo(Context).pointer.size != .one)
        @compileError("block context must be a single-item pointer");

    const fn_info = switch (@typeInfo(Handler)) {
        .@"fn" => |info| info,
        else => @compileError("block handler must be a function"),
    };
    if (fn_info.is_generic)
        @compileError("block handler cannot have anytype or comptime parameters");
    if (fn_info.attrs.varargs)
        @compileError("block handler cannot have C variadic parameters (...)");
    if (fn_info.param_types.len == 0)
        @compileError("block handler must take a context pointer as its first parameter");
    if (fn_info.param_types.len > 13)
        @compileError("block handler supports at most 12 block arguments, excluding context");
    if (fn_info.param_types[0].? != Context)
        @compileError("block handler's first parameter must match the context pointer type");

    const Block = BlockFromContextHandler(Context, fn_info);
    const Args = std.meta.ArgsTuple(@typeInfo(@FieldType(Block, "invoke")).pointer.child);
    const Static = struct {
        fn callback(args: Args) fn_info.return_type.? {
            var handler_args: std.meta.ArgsTuple(Handler) = undefined;
            handler_args[0] = args[0].context;
            inline for (1..fn_info.param_types.len) |i| handler_args[i] = args[i];
            return @call(.auto, handler, handler_args);
        }
    };

    return Block.init(ctx, obzc.utils.spreadArgs(Static.callback, .c));
}

fn BlockFromContextHandler(comptime Context: type, fn_info: std.lang.Type.Fn) type {
    var params: [fn_info.param_types.len - 1]type = undefined;
    for (fn_info.param_types[1..], 0..) |T, i| params[i] = T.?;
    const Function = @Fn(&params, &@splat(.{}), fn_info.return_type.?, .{});
    return obzc.Block(Context, Function);
}

test "initWithContext: forwards three arguments and mutates context" {
    const Handler = struct {
        fn invoke(value: *i32, delta: i32, multiplier: i32, offset: i32) void {
            value.* = (value.* + delta) * multiplier + offset;
        }
    };
    var value: i32 = 7;
    const block = initWithContext(&value, Handler.invoke);
    block.invoke(&block, 3, 2, 5);
    try std.testing.expectEqual(25, value);
}

test "initWithContext: argument forwarding, return value and heap copy" {
    const Context = struct { bias: i32 };
    const Handler = struct {
        fn invoke(ctx: *const Context, value: i32, scale: f64, offset: f64) f64 {
            return @as(f64, @floatFromInt(ctx.bias + value)) * scale + offset;
        }
    };
    const ctx: Context = .{ .bias = 7 };
    const block = initWithContext(&ctx, Handler.invoke);
    const copied = block.copy().?;
    defer copied.release();
    try std.testing.expectEqual(25.0, copied.invoke(copied, 3, 2.0, 5.0));
    try std.testing.expectEqualStrings("d@?idd", std.mem.span(copied.descriptor.signature));
}

test "initWithContext: context-only handler" {
    const Handler = struct {
        fn invoke(value: *i32) void {
            value.* += 1;
        }
    };
    var value: i32 = 7;
    const block = initWithContext(&value, Handler.invoke);
    block.invoke(&block);
    try std.testing.expectEqual(8, value);
}
