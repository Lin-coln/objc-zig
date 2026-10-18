const std = @import("std");
const c = @import("../c.zig").c;

pub const spreadArgs = @import("spreadArgs.zig").spreadArgs;
pub const spreadArgsWithCallback = @import("spreadArgsWithCallback.zig").spreadArgsWithCallback;
pub const spreadArgsWithReceiverAndCallback = @import("spreadArgsWithCallback.zig").spreadArgsWithReceiverAndCallback;

pub const cast = struct {
    pub fn @"bool"(value: c.BOOL) bool {
        return value != c.NO;
    }

    pub fn BOOL(value: bool) c.BOOL {
        return if (value) c.YES else c.NO;
    }
};

/// Resolves the last namespace component, omitting type factory arguments.
pub fn resolveTypeName(comptime full_name: []const u8) [:0]const u8 {
    var start: usize = 0;
    var end: usize = full_name.len;
    var depth: usize = 0;
    var quoted = false;
    var escaped = false;

    for (full_name, 0..) |char, i| {
        if (quoted) {
            if (escaped) {
                escaped = false;
            } else if (char == '\\') {
                escaped = true;
            } else if (char == '"') {
                quoted = false;
            }
            continue;
        }
        switch (char) {
            '"' => quoted = true,
            '(' => {
                if (depth == 0) end = i;
                depth += 1;
            },
            ')' => depth -= 1,
            '.' => if (depth == 0) {
                start = i + 1;
                end = full_name.len;
            },
            else => {},
        }
    }
    return std.fmt.comptimePrint("{s}", .{full_name[start..end]});
}

test "resolveTypeName: named and generated types" {
    const Types = struct {
        const Plain = opaque {};

        fn Generic(comptime T: type) type {
            return opaque {
                const Element = T;
            };
        }

        fn Pair(comptime A: type, comptime B: type) type {
            return opaque {
                const First = A;
                const Second = B;
            };
        }

        fn Text(comptime text: []const u8) type {
            return opaque {
                const value = text;
            };
        }

        fn Namespace(comptime T: type) type {
            return struct {
                const Plain = opaque {
                    const Element = T;
                };
            };
        }
    };
    const cases = .{
        .{ Types.Plain, "Plain" },
        .{ Types.Generic(u8), "Generic" },
        .{ Types.Generic(Types.Plain), "Generic" },
        .{ Types.Generic(Types.Generic(Types.Plain)), "Generic" },
        .{ Types.Pair(Types.Plain, Types.Generic(Types.Plain)), "Pair" },
        .{ Types.Text("a)b.c"), "Text" },
        .{ Types.Text("a(b.c"), "Text" },
        .{ Types.Text("a\"b).c"), "Text" },
        .{ Types.Namespace(Types.Plain).Plain, "Plain" },
    };
    inline for (cases) |case| {
        const name = comptime resolveTypeName(@typeName(case[0]));
        try std.testing.expectEqualStrings(case[1], name);
        try std.testing.expectEqual(@as(u8, 0), name.ptr[name.len]);
    }
}

test {
    _ = @import("spreadArgs.zig");
    _ = @import("spreadArgsWithCallback.zig");
}
