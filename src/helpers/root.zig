pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;

test {
    _ = @import("Class.zig");
    _ = @import("Object.zig");
}
