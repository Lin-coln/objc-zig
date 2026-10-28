const primitive = @import("primitive.zig");
const nested = @import("nested.zig");

pub fn encodeType(comptime T: type) []const u8 {
    const encoded: ?[]const u8 = switch (@typeInfo(T)) {
        // primitive
        .void => "v",
        .bool => "B",
        .int => |x| primitive.fromInt(x),
        .float => |x| primitive.fromFloat(x),

        // nested
        .@"enum" => |x| encodeType(x.tag_type),
        .@"struct" => |x| @import("struct.zig").fromStruct(encodeType, T, x, .val),
        .@"union" => |x| @import("struct.zig").fromUnion(encodeType, T, x, .val),
        .array => |x| nested.fromArray(encodeType, x),
        .optional => |x| nested.fromOptional(encodeType, x),
        .pointer => |x| nested.fromPointer(encodeType, x),

        else => null,
    };

    return encoded orelse
        @compileError(
            "cannot encode " ++
                @typeName(T) ++
                ":\nZig type category " ++
                @tagName(@typeInfo(T)) ++
                " has no supported Objective-C type encoding",
        );
}
