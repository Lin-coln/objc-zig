const std = @import("std");
const utils = @import("utils.zig");
const toSpreadedFn = @import("../../utils/root.zig").toSpreadedFn;

pub fn makeMethod(
    comptime Receiver: ?type,
    comptime call: anytype,
    comptime name: [:0]const u8,
    comptime Shape: type,
) type {
    const Resolved = resolveFromShape(Shape);

    const Args = if (Receiver) |R| @Tuple(&([_]type{R} ++ Resolved.types)) else @Tuple(&Resolved.types);

    return struct {
        pub const function = toSpreadedFn(invoke, .{ .cc = Resolved.cc });
        fn invoke(args: Args) Resolved.Return {
            if (comptime Receiver != null) {
                const CallArgs = @Tuple(&Resolved.types);
                var call_args: CallArgs = undefined;
                inline for (0..Resolved.types.len) |i| {
                    call_args[i] = args[i + 1];
                }
                return call(args[0], Resolved.Return, name, call_args);
            } else {
                return call(Resolved.Return, name, args);
            }
        }
    };
}

pub fn resolveFromShape(comptime Shape: type) type {
    const info = switch (@typeInfo(Shape)) {
        .@"fn" => |info| info,
        else => @compileError("Shape must be a function type"),
    };

    if (info.is_generic or info.attrs.varargs)
        @compileError("Shape must have fixed, non-generic parameters");

    comptime var param_types: [info.param_types.len]type = undefined;
    inline for (info.param_types, 0..) |p_type, i| {
        param_types[i] = p_type orelse
            @compileError("Shape parameters must have explicit types");
    }

    const resolved_types = param_types;

    return struct {
        pub const types = resolved_types;
        pub const cc = info.attrs.@"callconv";

        pub const Return = info.return_type orelse
            @compileError("Invalid Shape return found");
    };
}
