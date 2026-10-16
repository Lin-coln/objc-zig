// basic
pub const c = @import("c.zig").c;
pub const rt = @import("rt/root.zig");
pub const helpers = @import("helpers/root.zig");

// helpers
pub const Class = @import("Class.zig").Class;
pub const getClass = @import("Class.zig").getClass;

test {
    _ = @import("c.zig");
    _ = @import("rt/root.zig");
    _ = @import("helpers/root.zig");
    _ = @import("Class.zig");
}
