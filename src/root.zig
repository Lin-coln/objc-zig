pub const c = @import("c.zig").c;
pub const zig = @import("zig/root.zig");

pub const Object = @import("Object.zig");
pub const Class = @import("Class.zig").Class;
pub const getClass = @import("Class.zig").getClass;

pub const NSError = @import("NSError.zig").NSError;

test {
    _ = @import("c.zig");
    _ = @import("zig/root.zig");
    _ = @import("Object.zig");
    _ = @import("Class.zig");
}
