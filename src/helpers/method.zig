const std = @import("std");
const utils = @import("../utils/root.zig");

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

    const Static = struct {
        fn call(args: std.meta.ArgsTuple(Shape)) fn_info.return_type.? {
            return sender(fn_info.return_type.?, name, args);
        }
    };

    return utils.spreadArgs(Static.call, fn_info.attrs.@"callconv");
}

test "prependArgs: parameter order, return type and function attributes" {
    const Shape = fn (noalias *i32, f64) callconv(.c) usize;
    try std.testing.expect(prependArgs(Shape, &.{}) == Shape);
    const Prepended = prependArgs(Shape, &.{ *anyopaque, u8 });
    try std.testing.expect(Prepended == fn (*anyopaque, u8, noalias *i32, f64) callconv(.c) usize);
    try std.testing.expect(@typeInfo(Prepended).@"fn".param_attrs[2].@"noalias");
}
