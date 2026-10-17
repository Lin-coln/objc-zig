const std = @import("std");
const objc = @import("../root.zig");

/// Class helpers for a wrapper whose type or type factory is named after its Objective-C class.
pub fn Class(comptime T: type) type {
    const class_name = comptime resolveClassName(T);

    return struct {
        /// Sends `alloc` to the class, returning an uninitialized instance to be sent an `init...` message.
        pub fn alloc() *T {
            return msgSend(?*T, "alloc", .{}).?;
        }

        /// Sends `new` to the class, returning a newly allocated and initialized instance.
        pub fn new() *T {
            return msgSend(?*T, "new", .{}).?;
        }

        /// Sends the selector named `sel` to the class itself (a class method).
        pub fn msgSend(comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            return objc.rt.msgSend(getClass(), Return, objc.rt.Sel.registerName(sel), args);
        }

        /// Returns the Objective-C class bound to the wrapper type.
        pub fn getClass() *objc.rt.Class {
            return objc.rt.getClass(class_name).?;
        }
    };
}

/// Resolves the last namespace component, omitting type factory arguments.
fn resolveClassName(comptime T: type) [:0]const u8 {
    const full_name = @typeName(T);
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

test "resolveClassName: named and generated opaque types" {
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
        const name = comptime resolveClassName(case[0]);
        try std.testing.expectEqualStrings(case[1], name);
        try std.testing.expectEqual(@as(u8, 0), name.ptr[name.len]);
    }
}

test "helpers.Class: class messages, new and alloc" {
    const NSMutableData = opaque {};
    const h = Class(NSMutableData);
    const rt = objc.rt;
    const length = rt.Sel.registerName("length");
    const set_length = rt.Sel.registerName("setLength:");

    try std.testing.expectEqual(rt.getClass("NSMutableData").?, h.msgSend(*rt.Class, "class", .{}));

    const created = h.new();
    defer rt.release(@ptrCast(created));
    rt.msgSend(created, void, set_length, .{@as(usize, 5)});
    try std.testing.expectEqual(5, rt.msgSend(created, usize, length, .{}));

    const allocated = h.alloc();
    const initialized = rt.msgSend(allocated, ?*NSMutableData, rt.Sel.registerName("init"), .{}).?;
    defer rt.release(@ptrCast(initialized));
    rt.msgSend(initialized, void, set_length, .{@as(usize, 9)});
    try std.testing.expectEqual(9, rt.msgSend(initialized, usize, length, .{}));
}
