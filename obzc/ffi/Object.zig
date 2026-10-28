const Metadata = @import("../encode/root.zig").Metadata;

/// An Objective-C instance. Opaque so tagged pointers require no object alignment.
pub const Object = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
};
