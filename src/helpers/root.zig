pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;
pub const block = @import("block.zig");

test {
    _ = @import("Class.zig");
    _ = @import("Object.zig");
    _ = @import("block.zig");
}
