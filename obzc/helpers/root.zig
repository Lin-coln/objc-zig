pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;
pub const ClassFactory = @import("ClassFactory/root.zig").ClassFactory;

test {
    _ = @import("call.zig");
    _ = @import("prop.zig");
    _ = @import("method/root.zig");

    _ = @import("Class.zig");
    _ = @import("Object.zig");
    _ = @import("ClassFactory/root.zig");
}
