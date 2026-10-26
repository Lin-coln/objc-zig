pub const Class = @import("Class.zig").Class;

test {
    _ = @import("calling.zig");

    _ = @import("Class.zig");
}
