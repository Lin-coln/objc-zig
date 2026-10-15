// basic
pub const c = @import("c.zig").c;
pub const zig = @import("zig/root.zig");
pub const helpers = @import("helpers/root.zig");

// helpers
pub const Class = @import("Class.zig").Class;
pub const getClass = @import("Class.zig").getClass;

// advance
pub const ns = @import("ns/root.zig");

test {
    _ = @import("c.zig");
    _ = @import("zig/root.zig");
    _ = @import("helpers/root.zig");
    _ = @import("ns/root.zig");
    _ = @import("Class.zig");
}
