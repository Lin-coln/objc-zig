const std = @import("std");
const c = @import("c.zig").c;
const Property = @import("Property.zig").Property;
const Sel = @import("Sel.zig").Sel;

pub const Protocol = opaque {
    const Self = @This();

    pub fn lookup(name: [:0]const u8) ?*Self {
        return @ptrCast(c.objc_getProtocol(name));
    }
};
