const c = @import("../c.zig").c;

pub const cast = struct {
    pub fn @"bool"(value: c.BOOL) bool {
        return value != c.NO;
    }

    pub fn BOOL(value: bool) c.BOOL {
        return if (value) c.YES else c.NO;
    }
};
