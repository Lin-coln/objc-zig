pub const c = @import("c.zig").c;
pub const cast = @import("cast.zig");

pub const Sel = @import("Sel.zig").Sel;
pub const AutoReleasePool = @import("AutoReleasePool.zig").AutoReleasePool;

pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;
pub const msg = @import("msg.zig");

test {
    _ = @import("c.zig");
    _ = cast;
    _ = @import("Sel.zig");
    _ = @import("AutoReleasePool.zig");
    _ = @import("Class.zig");
    _ = @import("Object.zig");
    _ = @import("Property.zig");
    _ = msg;
}
