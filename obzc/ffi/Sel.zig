const std = @import("std");
const c = @import("c.zig").c;

pub const Sel = opaque {
    const Self = @This();

    /// Interns a selector name. Selectors have process lifetime.
    pub fn get(str: [:0]const u8) *Self {
        return @ptrCast(c.sel_registerName(str).?);
    }

    /// Returns the interned selector name. The string has process lifetime.
    pub fn name(self: *const Self) [:0]const u8 {
        return std.mem.span(c.sel_getName(@ptrCast(@constCast(self))));
    }
};

test "Sel.get and name: interned names round-trip" {
    inline for (.{ "", "init", "setValue:forKey:" }) |str| {
        const sel: *const Sel = Sel.get(str);
        try std.testing.expectEqualStrings(str, sel.name());
        try std.testing.expectEqual(sel, Sel.get(str));
        try std.testing.expectEqual(@as(u8, 0), sel.name().ptr[sel.name().len]);
    }
}
