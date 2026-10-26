pub const Class = @import("Class.zig").Class;

test {
    _ = @import("call.zig");
    _ = @import("prop.zig");

    _ = @import("Class.zig");
    _ = @import("Object.zig");
}
