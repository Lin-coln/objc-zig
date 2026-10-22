const std = @import("std");

pub fn resolveReceiverType(comptime T: type, comptime call: anytype) ?type {
    const info_call = switch (@typeInfo(@TypeOf(call))) {
        .@"fn" => |info| info,
        else => @compileError("call should be a fn"),
    };

    const Receiver: ?type = blk: {
        if (info_call.param_types.len < 1) break :blk null;
        const Arg0 = info_call.param_types[0] orelse break :blk null;
        const matches = switch (@typeInfo(Arg0)) {
            // *T or *const T
            .pointer => |ptr| ptr.size == .one and ptr.child == T,
            // T
            else => Arg0 == T,
        };
        break :blk if (matches) Arg0 else null;
    };

    return Receiver;
}

pub inline fn resolveFnInfo(
    comptime Shape: anytype,
    comptime opts: struct {
        generic: bool = false,
        varargs: bool = false,
        explicit: bool = true,
    },
) std.lang.Type.Fn {
    const info = switch (@typeInfo(Shape)) {
        .@"fn" => |info| info,
        else => @compileError("Shape must be a function type"),
    };

    if (info.return_type == null)
        @compileError("Shape return must have explicit type");

    if (info.is_generic and !opts.generic)
        @compileError("Shape cannot have generic parameters");

    if (info.attrs.varargs and !opts.varargs)
        @compileError("Shape cannot have C variadic parameters");

    if (opts.explicit) {
        inline for (info.param_types[0..info.param_types.len]) |p_type| {
            if (p_type == null)
                @compileError("Shape parameters must have explicit types");
        }
    }

    return info;
}
