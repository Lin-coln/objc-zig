const std = @import("std");
const c = @import("../c.zig").c;

pub const Sel = opaque {
    pub fn registerName(selector_name: [:0]const u8) *Sel {
        return @ptrCast(c.sel_registerName(selector_name).?);
    }

    pub fn name(self: *Sel) [:0]const u8 {
        return std.mem.span(c.sel_getName(@ptrCast(self)));
    }
};

test "Sel" {
    const sel = Sel.registerName("description");
    try std.testing.expectEqual(sel, Sel.registerName("description"));
    try std.testing.expectEqualStrings("description", sel.name());
}
