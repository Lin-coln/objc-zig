const std = @import("std");
pub const c = @import("c.zig").c;
pub const cast = @import("cast.zig");

pub const Sel = @import("Sel.zig").Sel;
pub const Protocol = @import("Protocol.zig").Protocol;
pub const AutoReleasePool = @import("AutoReleasePool.zig").AutoReleasePool;

pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;
pub const msg = @import("msg.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("Property.zig");
}
