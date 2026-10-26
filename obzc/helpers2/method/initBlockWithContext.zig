const std = @import("std");
const block = @import("../../block/root.zig");
const toSpreadedFn = @import("../../utils/root.zig").toSpreadedFn;

/// Creates a stack block for a handler receiving `ctx` and zero to twelve block arguments.
/// The context pointer must outlive every invocation, including heap copies.
pub fn initBlockWithContext(
    ctx: anytype,
    comptime handler: anytype,
) BlockFromContextHandler(@TypeOf(ctx), handlerInfo(@TypeOf(ctx), @TypeOf(handler))) {
    const Context = @TypeOf(ctx);
    const Handler = @TypeOf(handler);
    const fn_info = @typeInfo(Handler).@"fn";
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

    return Block.init(ctx, toSpreadedFn(Static.callback, .{ .cc = .c }));
}

/// Validates the handler before its parameter list is used to compute the returned Block type.
fn handlerInfo(comptime Context: type, comptime Handler: type) std.lang.Type.Fn {
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

    return fn_info;
}

fn BlockFromContextHandler(comptime Context: type, fn_info: std.lang.Type.Fn) type {
    var params: [fn_info.param_types.len - 1]type = undefined;
    for (fn_info.param_types[1..], 0..) |T, i| params[i] = T.?;
    const Function = @Fn(&params, &@splat(.{}), fn_info.return_type.?, .{});
    return block.Block(Context, Function);
}

test "helpers2.initBlockWithContext: routes stored context and arguments to the handler" {
    const State = struct { value: i32 = 0 };
    const Handler = struct {
        fn invoke(state: *State, value: i32, scale: i32) i32 {
            state.value = value;
            return value * scale;
        }
        fn empty(state: *State) void {
            state.value = 99;
        }
    };
    var state: State = .{};
    const with_args = initBlockWithContext(&state, Handler.invoke);
    try std.testing.expectEqual(@as(i32, 21), with_args.invoke(&with_args, 7, 3));
    try std.testing.expectEqual(@as(i32, 7), state.value);
    const empty = initBlockWithContext(&state, Handler.empty);
    empty.invoke(&empty);
    try std.testing.expectEqual(@as(i32, 99), state.value);
}

test "helpers2.handlerInfo: returns the validated handler information" {
    const Handler = fn (*u32, i32) bool;
    const info = handlerInfo(*u32, Handler);
    try std.testing.expect(info.param_types.len == 2);
    try std.testing.expect(info.param_types[0].? == *u32);
    try std.testing.expect(info.param_types[1].? == i32);
    try std.testing.expect(info.return_type.? == bool);
}

test "helpers2.BlockFromContextHandler: removes the context parameter from the block signature" {
    const B = BlockFromContextHandler(*u32, @typeInfo(fn (*u32, i32) bool).@"fn");
    try std.testing.expect(B == block.Block(*u32, fn (i32) bool));
}
