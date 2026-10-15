const std = @import("std");
const objc = @import("root.zig");

/// Returns a set of Objective-C object helpers bound to `T` (any opaque object type). Assemble a
/// wrapper by picking the pieces you want:
///
///     const h = Object.Helpers(Self);
///     pub const release = h.release;
///     pub const getWidth = h.prop(usize, "width").getter;
pub fn Helpers(comptime T: type) type {
    return struct {
        pub fn retain(self: *T) *T {
            return @ptrCast(objc.zig.retain(@ptrCast(self)));
        }

        pub fn release(self: *T) void {
            objc.zig.release(@ptrCast(self));
        }

        /// Sends the selector named `sel` to the object.
        pub fn msgSend(self: *T, comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            return objc.zig.msgSend(@as(*objc.zig.Object, @ptrCast(self)), Return, objc.zig.Sel.registerName(sel), args);
        }

        /// Reads the Objective-C property `name` as `P`. Honors a `getter=` declaration by resolving the
        /// property's `G` attribute at runtime, falling back to `name` itself as the getter selector.
        pub fn getProperty(self: *T, comptime P: type, name: [:0]const u8) P {
            const class = @as(*objc.zig.Object, @ptrCast(self)).getClass();
            if (class.getProperty(name)) |property| {
                if (property.copyAttributeValue("G")) |getter| {
                    defer std.c.free(getter.ptr);
                    return msgSend(self, P, getter, .{});
                }
            }
            return msgSend(self, P, name, .{});
        }

        /// Writes `value` to the Objective-C property `name` via its `set<Name>:` setter.
        pub fn setProperty(self: *T, comptime name: [:0]const u8, value: anytype) void {
            const setter = "set" ++ [_]u8{std.ascii.toUpper(name[0])} ++ name[1..] ++ ":";
            msgSend(self, void, setter, .{value});
        }

        /// Accessor methods for the property `name` of type `P`:
        ///
        ///     pub const getWidth = h.prop(usize, "width").getter;
        ///     pub const setWidth = h.prop(usize, "width").setter;
        pub fn prop(comptime P: type, comptime name: [:0]const u8) type {
            return struct {
                pub fn getter(self: *T) P {
                    return getProperty(self, P, name);
                }
                pub fn setter(self: *T, value: P) void {
                    setProperty(self, name, value);
                }
            };
        }
    };
}

test "Helpers: getProperty / setProperty" {
    const h = Helpers(objc.zig.Object);
    const data = objc.zig.msgSend(objc.zig.getClass("NSMutableData").?, ?*objc.zig.Object, objc.zig.Sel.registerName("new"), .{}).?;
    defer h.release(data);

    h.setProperty(data, "length", @as(usize, 8));
    try std.testing.expectEqual(8, h.getProperty(data, usize, "length"));
}
