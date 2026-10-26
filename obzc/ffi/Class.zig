const c = @import("c.zig").c;

pub const Class = opaque {
    const Self = @This();

    /// Looks up an already registered class. Does not allocate or initialize an object.
    pub fn lookup(name: [:0]const u8) ?*Self {
        return @ptrCast(c.objc_getClass(name));
    }
};
