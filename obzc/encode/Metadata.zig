const std = @import("std");
const Type = std.lang.Type;

const Self = @This();
encoding: Encoding,

pub const Encoding = enum {
    cls, // #
    obj, // @
    sel, // :

    fn encode(self: Encoding) []const u8 {
        switch (self) {
            .cls => "#",
            .obj => "@",
            .sel => ":",
        }
    }
};

pub fn fromPointer(info: Type.Pointer) ?Self {
    const T = info.child;
    if (@typeInfo(T) != .@"opaque") return null;
    if (!@hasDecl(T, "metadata")) return null;
    return T.metadata;
}
