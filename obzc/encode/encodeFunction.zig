const std = @import("std");
const encodeType = @import("encode.zig").encodeType;

pub inline fn encodeFunction(
    comptime Fn: type,
    comptime implicit_encoding: []const u8,
) [:0]const u8 {
    const info = switch (@typeInfo(Fn)) {
        .@"fn" => |info| info,
        else => @compileError("encodeFunction expects a function type"),
    };
    if (info.is_generic or info.attrs.varargs)
        @compileError("encodeFunction requires a non-generic function with fixed parameters");
    var result: []const u8 = comptime encodeType(info.return_type.?);
    result = result ++ implicit_encoding;
    inline for (info.param_types) |Param| {
        result = result ++ encodeType(Param.?);
    }
    return std.fmt.comptimePrint("{s}", .{result});
}

test "encodeFunction: encodes return, implicit encoding, and all parameters" {
    const Metadata = @import("Metadata.zig");
    const Object = opaque {
        pub const metadata = Metadata.obj;
    };
    const Sel = opaque {
        pub const metadata = Metadata.sel;
    };
    const cases = .{
        .{ fn (*Object, *Sel) void, "", "v@:" },
        .{ fn (*Object, *Sel, i32, f64) u64, "", "Q@:id" },
        .{ fn (i32) void, "@?", "v@?i" },
    };
    inline for (cases) |case| {
        const result = comptime encodeFunction(case[0], case[1]);
        try std.testing.expectEqualStrings(case[2], result);
        try std.testing.expectEqual(@as(u8, 0), result.ptr[result.len]);
    }
}
