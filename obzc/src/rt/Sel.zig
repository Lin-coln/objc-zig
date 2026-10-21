const std = @import("std");
const c = @import("../c.zig").c;

pub const Sel = opaque {
    pub fn registerName(selector_name: [:0]const u8) *Sel {
        return @ptrCast(c.sel_registerName(selector_name).?);
    }

    pub fn getName(self: *Sel) [:0]const u8 {
        return std.mem.span(c.sel_getName(@ptrCast(self)));
    }
};

test "Sel: registerName interns selector names" {
    const sel = Sel.registerName("description");
    try std.testing.expectEqual(sel, Sel.registerName("description"));
    try std.testing.expect(sel != Sel.registerName("debugDescription"));
}

test "Sel: getName returns the registered name" {
    const sel = Sel.registerName("description");
    try std.testing.expectEqualStrings("description", sel.getName());
}
