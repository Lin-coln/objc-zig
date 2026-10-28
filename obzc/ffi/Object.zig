const Metadata = @import("../encode/Metadata.zig");

/// An Objective-C instance. Opaque so tagged pointers require no object alignment.
pub const Object = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
};
