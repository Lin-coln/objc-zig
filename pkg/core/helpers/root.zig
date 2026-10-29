const std = @import("std");
pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;
pub const ClassFactory = @import("ClassFactory/root.zig").ClassFactory;

test {
    std.testing.refAllDecls(@This());
    _ = @import("call.zig");
    _ = @import("prop.zig");
    _ = @import("ivar.zig");
    _ = @import("method/root.zig");
}
