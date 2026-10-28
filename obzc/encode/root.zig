pub const Metadata = @import("Metadata.zig");

pub inline fn encode(comptime T: type) []const u8 {
    return comptime @import("encode.zig").encodeType(T);
}

test {
    _ = Metadata;
    _ = @import("encode.zig");
    _ = @import("primitive.zig");
    _ = @import("nested.zig");
    _ = @import("struct.zig");
}
