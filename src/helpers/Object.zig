const std = @import("std");
const objc = @import("../root.zig");
const cast = objc.rt.utils.cast;

/// Returns a set of Objective-C object helpers bound to `T` (any opaque object type). Assemble a
/// wrapper by picking the pieces you want:
///
///     const h = objc.helpers.Object(Self);
///     pub const release = h.release;
///     pub const width = h.prop(usize, "width").getter;
pub fn Object(comptime T: type) type {
    return struct {
        pub fn retain(self: *T) *T {
            return @ptrCast(objc.rt.retain(@ptrCast(self)));
        }

        pub fn release(self: *T) void {
            objc.rt.release(@ptrCast(self));
        }

        /// Sends the selector named `sel` to the object.
        pub fn msgSend(self: *T, comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            return objc.rt.msgSend(@as(*objc.rt.Object, @ptrCast(self)), Return, objc.rt.Sel.registerName(sel), args);
        }

        /// Reads the Objective-C property `name` as `P`. Honors a `getter=` declaration by resolving the
        /// property's `G` attribute at runtime, falling back to `name` itself as the getter selector.
        pub fn property(self: *T, comptime P: type, name: [:0]const u8) P {
            const class = @as(*objc.rt.Object, @ptrCast(self)).getClass();
            const getter = if (class.getProperty(name)) |metadata| metadata.copyAttributeValue("G") else null;
            defer if (getter) |custom| std.c.free(custom.ptr);

            const selector = getter orelse name;
            if (P == bool) return cast.bool(msgSend(self, objc.c.BOOL, selector, .{}));
            return msgSend(self, P, selector, .{});
        }

        /// Writes `value` to the Objective-C property `name` via its `set<Name>:` setter.
        pub fn setProperty(self: *T, comptime name: [:0]const u8, value: anytype) void {
            const setter = "set" ++ [_]u8{std.ascii.toUpper(name[0])} ++ name[1..] ++ ":";
            if (@TypeOf(value) == bool) {
                msgSend(self, void, setter, .{cast.BOOL(value)});
            } else {
                msgSend(self, void, setter, .{value});
            }
        }

        /// Accessor methods for the property `name` of type `P`:
        ///
        ///     pub const width = h.prop(usize, "width").getter;
        ///     pub const setWidth = h.prop(usize, "width").setter;
        pub fn prop(comptime P: type, comptime name: [:0]const u8) type {
            return struct {
                pub fn getter(self: *T) P {
                    return property(self, P, name);
                }
                pub fn setter(self: *T, value: P) void {
                    setProperty(self, name, value);
                }
            };
        }
    };
}

test "helpers.Object: property / setProperty" {
    const h = Object(objc.rt.Object);
    const data = objc.rt.msgSend(objc.rt.getClass("NSMutableData").?, ?*objc.rt.Object, objc.rt.Sel.registerName("new"), .{}).?;
    defer h.release(data);

    h.setProperty(data, "length", @as(usize, 8));
    try std.testing.expectEqual(8, h.property(data, usize, "length"));
}

test "helpers.Object: prop getter and setter" {
    const h = Object(objc.rt.Object);
    const length = h.prop(usize, "length");
    const data = objc.rt.msgSend(objc.rt.getClass("NSMutableData").?, ?*objc.rt.Object, objc.rt.Sel.registerName("new"), .{}).?;
    defer h.release(data);

    length.setter(data, 12);
    try std.testing.expectEqual(12, length.getter(data));
}

test "helpers.Object: property honors a custom getter" {
    const h = Object(objc.rt.Object);
    const operation = objc.rt.msgSend(objc.rt.getClass("NSOperation").?, ?*objc.rt.Object, objc.rt.Sel.registerName("new"), .{}).?;
    defer h.release(operation);

    const cancelled = operation.getClass().getProperty("cancelled").?;
    const getter = cancelled.copyAttributeValue("G").?;
    defer std.c.free(getter.ptr);
    try std.testing.expectEqualStrings("isCancelled", getter);

    try std.testing.expectEqual(false, h.property(operation, bool, "cancelled"));
    h.msgSend(operation, void, "cancel", .{});
    try std.testing.expectEqual(true, h.property(operation, bool, "cancelled"));
}
