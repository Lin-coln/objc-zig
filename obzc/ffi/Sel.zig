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

test "Sel.get: forwards the requested selector name" {
    inline for (.{ "", "init", "setValue:forKey:" }) |str| {
        const sel = Sel.get(str);
        try std.testing.expectEqualStrings(str, std.mem.span(c.sel_getName(@ptrCast(sel))));
    }
}

test "Sel.name: returns a const sentinel slice for the supplied selector" {
    inline for (.{ "", "init", "setValue:forKey:" }) |str| {
        const sel: *const Sel = @ptrCast(c.sel_registerName(str).?);
        const name = sel.name();
        try std.testing.expectEqualStrings(str, name);
        try std.testing.expectEqual(@as(u8, 0), name.ptr[name.len]);
    }
}
