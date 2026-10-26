const std = @import("std");

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

test "resolveFnInfo accepts fixed and explicitly typed generic shapes" {
    const Calls = struct {
        fn typedGeneric(comptime _: u32) void {}
    };
    const fixed = resolveFnInfo(fn (u8) callconv(.c) u16, .{});
    try std.testing.expect(fixed.param_types[0].? == u8);
    try std.testing.expect(fixed.return_type.? == u16);
    try std.testing.expect(std.meta.eql(fixed.attrs.@"callconv", std.lang.CallingConvention.c));

    const generic = resolveFnInfo(@TypeOf(Calls.typedGeneric), .{ .generic = true });
    try std.testing.expect(generic.is_generic);
    try std.testing.expect(generic.param_types[0].? == u32);
}

test "resolveFnInfo permits variadic and inferred parameters only when requested" {
    const variadic = resolveFnInfo(fn (i32, ...) callconv(.c) void, .{ .varargs = true });
    try std.testing.expect(variadic.attrs.varargs);
    const generic = resolveFnInfo(fn (anytype) void, .{ .generic = true, .explicit = false });
    try std.testing.expect(generic.is_generic);
    try std.testing.expect(generic.param_types[0] == null);
}
