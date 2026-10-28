const std = @import("std");
const Type = std.lang.Type;

pub const Encoding = enum {
    cls, // #
    obj, // @
    sel, // :

    pub fn encode(self: Encoding) []const u8 {
        return switch (self) {
            .cls => "#",
            .obj => "@",
            .sel => ":",
        };
    }
};

const Self = @This();
encoding: Encoding,

pub const obj: Self = .{ .encoding = .obj };

pub fn fromPointer(info: Type.Pointer) ?Self {
    const T = info.child;
    if (@typeInfo(T) != .@"opaque") return null;
    if (!@hasDecl(T, "metadata")) return null;
    return T.metadata;
}

test "Encoding.encode: maps Objective-C metadata tags" {
    try std.testing.expectEqualStrings("#", Encoding.cls.encode());
    try std.testing.expectEqualStrings("@", Encoding.obj.encode());
    try std.testing.expectEqualStrings(":", Encoding.sel.encode());
}

test "fromPointer: reads an opaque pointee's metadata when present" {
    const Annotated = opaque {
        pub const metadata: Self = .{ .encoding = .obj };
    };
    const Plain = opaque {};
    const Concrete = extern struct { value: u8 };

    try std.testing.expectEqual(Encoding.obj, (comptime fromPointer(@typeInfo(*Annotated).pointer)).?.encoding);
    try std.testing.expectEqual(null, comptime fromPointer(@typeInfo(*Plain).pointer));
    try std.testing.expectEqual(null, comptime fromPointer(@typeInfo(*Concrete).pointer));
}
