const std = @import("std");

pub const Metadata = @import("Metadata.zig");

pub const encodeFunction = @import("encodeFunction.zig").encodeFunction;

pub inline fn encodeType(comptime T: type) [:0]const u8 {
    return comptime std.fmt.comptimePrint("{s}", .{
        @import("encode.zig").encodeType(T),
    });
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("encode.zig");
    _ = @import("primitive.zig");
    _ = @import("nested.zig");
    _ = @import("struct.zig");
}
