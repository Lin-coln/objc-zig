const std = @import("std");
const encodeType = @import("encode.zig").encodeType;

pub inline fn encodeFunction(
    comptime Fn: type,
    comptime skipped_params: usize,
    comptime implicit_encoding: []const u8,
) [:0]const u8 {
    const info = switch (@typeInfo(Fn)) {
        .@"fn" => |info| info,
        else => @compileError("encodeFunction expects a function type"),
    };
    if (info.is_generic or info.attrs.varargs)
        @compileError("encodeFunction requires a non-generic function with fixed parameters");
    if (skipped_params > info.param_types.len)
        @compileError("skipped_params exceeds the function parameter count");

    var result: []const u8 = comptime encodeType(info.return_type.?);
    result = result ++ implicit_encoding;
    inline for (info.param_types[skipped_params..]) |Param| {
        result = result ++ encodeType(Param.?);
    }
    return std.fmt.comptimePrint("{s}", .{result});
}

test "encodeFunction: encodes return and explicit parameters around implicit encoding" {
    const cases = .{
        .{ fn (*anyopaque, *anyopaque) void, 2, "@:", "v@:" },
        .{ fn (*anyopaque, *anyopaque, i32, f64) u64, 2, "@:", "Q@:id" },
        .{ fn (i32) void, 0, "@?", "v@?i" },
    };
    inline for (cases) |case| {
        const result = comptime encodeFunction(case[0], case[1], case[2]);
        try std.testing.expectEqualStrings(case[3], result);
        try std.testing.expectEqual(@as(u8, 0), result.ptr[result.len]);
    }
}
