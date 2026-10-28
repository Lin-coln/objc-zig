const std = @import("std");
const Type = std.lang.Type;

pub const Metadata = struct {
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
};

pub fn resolveEncoding(info: Type.Pointer) ?[]const u8 {
    const T = info.child;
    if (@typeInfo(T) != .@"opaque") return null;
    if (!@hasDecl(T, "metadata")) return null;
    const metadata: Metadata = T.metadata;
    return metadata.encoding.encode();
}
