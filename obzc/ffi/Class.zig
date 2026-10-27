const std = @import("std");
const c = @import("c.zig").c;
const Property = @import("Property.zig").Property;
const Sel = @import("Sel.zig").Sel;

pub const Class = opaque {
    const Self = @This();

    pub fn lookup(name: [:0]const u8) ?*Self {
        return @ptrCast(c.objc_getClass(name));
    }

    pub fn getProperty(self: *Self, name: [:0]const u8) ?*Property {
        return @ptrCast(c.class_getProperty(@ptrCast(self), name));
    }

    // ClassPair
    pub fn metaclass(self: *Self) ?*Self {
        return @ptrCast(c.object_getClass(@ptrCast(self)));
    }

    pub fn dispose(self: *Self) void {
        c.objc_disposeClassPair(@ptrCast(self));
    }

    pub fn register(self: *Self) void {
        c.objc_registerClassPair(@ptrCast(self));
    }
};

test "Class.lookup: forwards the class name and preserves a missing result" {
    const object = Class.lookup("NSObject").?;
    const number = Class.lookup("NSNumber").?;
    try std.testing.expectEqualStrings("NSObject", std.mem.span(c.class_getName(@ptrCast(object))));
    try std.testing.expectEqualStrings("NSNumber", std.mem.span(c.class_getName(@ptrCast(number))));
    try std.testing.expectEqual(null, Class.lookup("ObzcFfiMissingClass"));
}

test "Class.getProperty: forwards the class and property name and preserves missing results" {
    const string = Class.lookup("NSString").?;
    const operation = Class.lookup("NSOperation").?;
    const length = string.getProperty("length").?;
    const cancelled = operation.getProperty("cancelled").?;
    try std.testing.expectEqualStrings("length", std.mem.span(c.property_getName(@ptrCast(length))));
    try std.testing.expectEqualStrings("cancelled", std.mem.span(c.property_getName(@ptrCast(cancelled))));
    try std.testing.expectEqual(null, string.getProperty("cancelled"));
    try std.testing.expectEqual(null, operation.getProperty("ObzcFfiMissingProperty"));
}

test "Class.metaclass: returns the metaclass of the supplied class" {
    const first: *Class = @ptrCast(c.objc_getClass("NSObject").?);
    const second: *Class = @ptrCast(c.objc_getClass("NSNumber").?);
    try std.testing.expectEqual(c.object_getClass(@ptrCast(first)), @as(c.Class, @ptrCast(first.metaclass())));
    try std.testing.expectEqual(c.object_getClass(@ptrCast(second)), @as(c.Class, @ptrCast(second.metaclass())));
}

test "Class.register: registers the supplied allocated class" {
    const name = "ObzcFfiClassRegisterProbe";
    const raw = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, name, 0).?;
    defer c.objc_disposeClassPair(raw);
    const cls: *Class = @ptrCast(raw);
    try std.testing.expectEqual(null, c.objc_getClass(name));
    cls.register();
    try std.testing.expectEqual(@as(c.Class, raw), c.objc_getClass(name));
}

test "Class.dispose: removes the supplied class from runtime lookup" {
    const name = "ObzcFfiClassDisposeProbe";
    const raw = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, name, 0).?;
    const cls: *Class = @ptrCast(raw);
    c.objc_registerClassPair(raw);
    cls.dispose();
    try std.testing.expectEqual(null, c.objc_getClass(name));
    const replacement = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, name, 0).?;
    defer c.objc_disposeClassPair(replacement);
}
