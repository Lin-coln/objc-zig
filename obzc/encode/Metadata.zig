const std = @import("std");
const Type = std.lang.Type;

pub const Encoding = enum {
    cls, // #
    obj, // @
    sel, // :
    blk, // @?

    pub fn encode(self: Encoding) []const u8 {
        return switch (self) {
            .cls => "#",
            .obj => "@",
            .sel => ":",
            .blk => "@?",
        };
    }
};

const Self = @This();
encoding: Encoding,

pub const obj: Self = .{ .encoding = .obj };
pub const cls: Self = .{ .encoding = .cls };
pub const sel: Self = .{ .encoding = .sel };

pub fn fromPointer(info: Type.Pointer) ?Self {
    const T = info.child;
    switch (@typeInfo(T)) {
        .@"opaque", .@"struct" => {},
        else => return null,
    }
    if (!@hasDecl(T, "metadata")) return null;
    return T.metadata;
}

test "Encoding.encode: maps Objective-C metadata tags" {
    try std.testing.expectEqualStrings("#", Encoding.cls.encode());
    try std.testing.expectEqualStrings("@", Encoding.obj.encode());
    try std.testing.expectEqualStrings(":", Encoding.sel.encode());
    try std.testing.expectEqualStrings("@?", Encoding.blk.encode());
}

test "fromPointer: reads opaque and struct pointee metadata when present" {
    const Annotated = opaque {
        pub const metadata: Self = .{ .encoding = .obj };
    };
    const Plain = opaque {};
    const Concrete = extern struct { value: u8 };
    const Block = extern struct {
        pub const metadata: Self = .{ .encoding = .blk };
        value: u8,
    };

    try std.testing.expectEqual(Encoding.obj, (comptime fromPointer(@typeInfo(*Annotated).pointer)).?.encoding);
    try std.testing.expectEqual(Encoding.blk, (comptime fromPointer(@typeInfo(*const Block).pointer)).?.encoding);
    try std.testing.expectEqual(null, comptime fromPointer(@typeInfo(*Plain).pointer));
    try std.testing.expectEqual(null, comptime fromPointer(@typeInfo(*Concrete).pointer));
}
