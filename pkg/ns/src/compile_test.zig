const std = @import("std");
pub const sources = .{
    @import("NSNumber.test.zig"),
};

test {
    std.testing.refAllDecls(@This());
}
