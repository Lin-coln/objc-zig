const std = @import("std");
const Metadata = @import("Metadata.zig");
const Type = std.lang.Type;

pub fn fromArray(encode: anytype, info: Type.Array) ?[]const u8 {
    const el = encode(info.child);

    const len = if (info.sentinel_ptr != null)
        info.len + 1
    else
        info.len;
    return std.fmt.comptimePrint("[{d}{s}]", .{ len, el });
}

pub fn fromOptional(encode: anytype, info: Type.Optional) ?[]const u8 {
    const info_child = switch (@typeInfo(info.child)) {
        .pointer => |x| x,
        else => return null,
    };

    if (info_child.attrs.@"allowzero") return null;

    if (info_child.size == .slice) return null;

    if (info_child.size == .c) return null;

    return encode(info.child);
}

pub fn fromPointer(encode: anytype, info: Type.Pointer) ?[]const u8 {
    // slice
    if (info.size == .slice) return null;

    // c string
    if (info.child == u8 and switch (info.size) {
        .c => true,
        .many => info.sentinel_ptr != null,
        else => false,
    }) {
        return "*";
    }

    // resolve from metadata
    if (Metadata.fromPointer(info)) |metadata| {
        return metadata.encoding.encode();
    }

    // regular ptr
    const suffix: ?[]const u8 = switch (@typeInfo(info.child)) {
        .@"fn" => "?",
        .@"struct" => |x| @import("struct.zig").fromStruct(encode, info.child, x, .ref),
        .@"union" => |x| @import("struct.zig").fromUnion(encode, info.child, x, .ref),
        .@"opaque" => "v",
        else => encode(info.child),
    };

    return "^" ++ (suffix orelse return null);
}

test "fromArray: counts the sentinel and encodes its element" {
    const Stub = struct {
        fn encode(comptime _: type) []const u8 {
            return "X";
        }
    };
    try std.testing.expectEqualStrings("[2X]", comptime fromArray(Stub.encode, @typeInfo([2]u8).array).?);
    try std.testing.expectEqualStrings("[3X]", comptime fromArray(Stub.encode, @typeInfo([2:0]u8).array).?);
}

test "fromOptional: accepts only nullable pointer layouts" {
    const Stub = struct {
        fn encode(comptime _: type) []const u8 {
            return "P";
        }
    };
    try std.testing.expectEqualStrings("P", comptime fromOptional(Stub.encode, @typeInfo(?*i32).optional).?);
    try std.testing.expectEqual(null, comptime fromOptional(Stub.encode, @typeInfo(?u32).optional));
    try std.testing.expectEqual(null, comptime fromOptional(Stub.encode, @typeInfo(?[]u8).optional));
    try std.testing.expectEqual(null, comptime fromOptional(Stub.encode, @typeInfo(?[*c]u8).optional));
    try std.testing.expectEqual(null, comptime fromOptional(Stub.encode, @typeInfo(?*allowzero i32).optional));
}

test "fromPointer: handles string, metadata, function, opaque and ordinary pointers" {
    const Stub = struct {
        fn encode(comptime _: type) []const u8 {
            return "X";
        }
    };
    const Annotated = opaque {
        pub const metadata: Metadata = .{ .encoding = .sel };
    };
    const Plain = opaque {};

    const cases = .{
        .{ [*:0]const u8, "*" },
        .{ [*c]u8, "*" },
        .{ *Annotated, ":" },
        .{ *Plain, "^v" },
        .{ *const fn () callconv(.c) void, "^?" },
        .{ *i32, "^X" },
    };
    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], comptime fromPointer(Stub.encode, @typeInfo(case[0]).pointer).?);
    }
    try std.testing.expectEqual(null, comptime fromPointer(Stub.encode, @typeInfo([]u8).pointer));
}
