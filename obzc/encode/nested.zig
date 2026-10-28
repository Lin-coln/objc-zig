const std = @import("std");
const Type = std.lang.Type;

pub fn fromArray(encode: anytype, info: Type.Array) ?[]const u8 {
    const el = encode(info.child) orelse
        return null;

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

    // custom encoding
    if (@import("custom.zig").resolveEncoding(info)) |res| return res;

    // regular ptr
    const suffix = switch (@typeInfo(info.child)) {
        .@"fn" => "?",
        .@"struct" => |x| @import("struct.zig").fromStruct(encode, info.child, x, .ref),
        .@"union" => |x| @import("struct.zig").fromUnion(encode, info.child, x, .ref),
        .@"opaque" => "v",
        else => encode(info.child),
    } orelse
        return null;

    return "^" ++ suffix;
}
