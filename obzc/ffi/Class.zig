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

    pub fn addMethod(
        self: *Self,
        sel: *Sel,
        imp: c.IMP,
        signature: [:0]const u8,
    ) bool {
        const done = c.class_addMethod(@ptrCast(self), @ptrCast(sel), imp, signature);
        return done == c.YES;
    }

    /// Adds an ivar before registration. `alignment` is log2 of its alignment in bytes.
    pub fn addIvar(
        self: *Self,
        name: [:0]const u8,
        size: usize,
        alignment: u8,
        signature: [:0]const u8,
    ) bool {
        return c.class_addIvar(@ptrCast(self), name, size, alignment, signature) == c.YES;
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

test "Class.addMethod: forwards selector implementation and signature and preserves duplicate failure" {
    const Probe = struct {
        fn first(_: c.id, _: c.SEL, value: i32) callconv(.c) i32 {
            return value;
        }
        fn second(_: c.id, _: c.SEL, _: i32) callconv(.c) i32 {
            return 0;
        }
    };
    const raw = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcFfiClassAddMethodProbe", 0).?;
    defer c.objc_disposeClassPair(raw);
    c.objc_registerClassPair(raw);
    const cls: *Class = @ptrCast(raw);
    const sel: *Sel = @ptrCast(c.sel_registerName("probe:").?);
    const imp: c.IMP = @ptrCast(&Probe.first);
    try std.testing.expect(cls.addMethod(sel, imp, "i@:i"));
    const metadata = c.class_getInstanceMethod(raw, @ptrCast(sel)).?;
    try std.testing.expectEqual(imp, c.method_getImplementation(metadata));
    try std.testing.expectEqualStrings("i@:i", std.mem.span(c.method_getTypeEncoding(metadata)));
    try std.testing.expect(!cls.addMethod(sel, @ptrCast(&Probe.second), "i@:i"));
    try std.testing.expectEqual(imp, c.method_getImplementation(metadata));
}

test "Class.addIvar: forwards layout and signature and preserves failure" {
    const raw = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcFfiClassAddIvarProbe", 0).?;
    defer c.objc_disposeClassPair(raw);
    const cls: *Class = @ptrCast(raw);
    const base_size = c.class_getInstanceSize(raw);
    try std.testing.expect(c.class_addIvar(raw, "_prefix", 1, 0, "C") == c.YES);
    try std.testing.expect(cls.addIvar("_value", 16, 4, "[16C]"));
    try std.testing.expect(!cls.addIvar("_value", 16, 4, "[16C]"));
    try std.testing.expect(c.class_addIvar(raw, "_tail", 1, 0, "C") == c.YES);
    c.objc_registerClassPair(raw);

    const value = c.class_getInstanceVariable(raw, "_value").?;
    const offset = std.mem.alignForward(usize, base_size + 1, 16);
    try std.testing.expectEqual(@as(isize, @intCast(offset)), c.ivar_getOffset(value));
    try std.testing.expectEqualStrings("[16C]", std.mem.span(c.ivar_getTypeEncoding(value)));
    const tail = c.class_getInstanceVariable(raw, "_tail").?;
    try std.testing.expectEqual(@as(isize, @intCast(offset + 16)), c.ivar_getOffset(tail));
    try std.testing.expect(!cls.addIvar("_late", 1, 0, "C"));
}
