const std = @import("std");

const SpreadOptions = struct {
    cc: ?std.lang.CallingConvention = null,
};

fn SpreadFnType(comptime Handle: type, comptime opts: SpreadOptions) type {
    const info = @typeInfo(Handle).@"fn";
    const Args = info.param_types[0].?;
    const types = @typeInfo(Args).@"struct".field_types;
    const attrs: [types.len]std.lang.Type.Fn.ParamAttributes = @splat(.{});

    var attrs_fn = info.attrs;
    attrs_fn.@"callconv" = opts.cc orelse info.attrs.@"callconv";

    return @Fn(
        types,
        &attrs,
        info.return_type.?,
        attrs_fn,
    );
}

pub fn toSpreadedFn(comptime handle: anytype, comptime opts: SpreadOptions) SpreadFnType(@TypeOf(handle), opts) {
    const info = @typeInfo(@TypeOf(handle)).@"fn";

    if (info.attrs.varargs)
        @compileError("Variadic functions are not supported");

    const Args = info.param_types[0].?;
    const R = info.return_type.?;
    const cc = opts.cc orelse info.attrs.@"callconv";
    const f = @typeInfo(Args).@"struct".field_types;

    const Wrapper = switch (f.len) {
        0 => struct {
            fn c() callconv(cc) R {
                return handle(.{});
            }
        },
        1 => struct {
            fn c(a0: f[0]) callconv(cc) R {
                return handle(.{a0});
            }
        },
        2 => struct {
            fn c(a0: f[0], a1: f[1]) callconv(cc) R {
                return handle(.{ a0, a1 });
            }
        },
        3 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2]) callconv(cc) R {
                return handle(.{ a0, a1, a2 });
            }
        },
        4 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3 });
            }
        },
        5 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4 });
            }
        },
        6 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5 });
            }
        },
        7 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6 });
            }
        },
        8 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7 });
            }
        },
        9 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7, a8 });
            }
        },
        10 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9 });
            }
        },
        11 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 });
            }
        },
        12 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 });
            }
        },
        13 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 });
            }
        },
        14 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], a13: f[13]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 });
            }
        },
        15 => struct {
            fn c(a0: f[0], a1: f[1], a2: f[2], a3: f[3], a4: f[4], a5: f[5], a6: f[6], a7: f[7], a8: f[8], a9: f[9], a10: f[10], a11: f[11], a12: f[12], a13: f[13], a14: f[14]) callconv(cc) R {
                return handle(.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14 });
            }
        },
        else => @compileError("Unsupported argument count"),
    };

    return Wrapper.c;
}
