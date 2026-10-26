pub const c = @import("c.zig").c;
pub const cast = @import("cast.zig");

test {
    _ = @import("c.zig");
    _ = @import("cast.zig");
}
