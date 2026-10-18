const std = @import("std");
const c = @import("../c.zig").c;
const Sel = @import("Sel.zig").Sel;
const Protocol = @import("Protocol.zig").Protocol;
const Ivar = @import("Ivar.zig").Ivar;
const Method = @import("Method.zig").Method;
const Property = @import("Property.zig").Property;

pub const Class = opaque {
    pub fn getName(self: *Class) [:0]const u8 {
        return std.mem.span(c.class_getName(@ptrCast(self)));
    }

    pub fn getSuperclass(self: *Class) ?*Class {
        return @ptrCast(c.class_getSuperclass(@ptrCast(self)));
    }

    pub fn getInstanceSize(self: *Class) usize {
        return c.class_getInstanceSize(@ptrCast(self));
    }

    pub fn isMetaClass(self: *Class) bool {
        return c.class_isMetaClass(@ptrCast(self)) == c.YES;
    }

    pub fn respondsToSelector(self: *Class, sel: *Sel) bool {
        return c.class_respondsToSelector(@ptrCast(self), @ptrCast(sel)) == c.YES;
    }

    /// `imp` is a pointer to a `callconv(.c)` function whose first two parameters are the receiver and `SEL`,
    /// matching the Objective-C type encoding `types`.
    pub fn addMethod(self: *Class, sel: *Sel, imp: anytype, types: [:0]const u8) bool {
        return c.class_addMethod(@ptrCast(self), @ptrCast(sel), @ptrCast(imp), types) == c.YES;
    }

    /// Adds the method if it does not exist yet, in which case `types` is used and null is returned.
    /// Otherwise replaces its implementation, ignores `types` and returns the previous implementation.
    /// `imp` follows the same rules as in `addMethod`.
    pub fn replaceMethod(self: *Class, sel: *Sel, imp: anytype, types: [:0]const u8) c.IMP {
        return c.class_replaceMethod(@ptrCast(self), @ptrCast(sel), @ptrCast(imp), types);
    }

    pub fn addProtocol(self: *Class, protocol: *Protocol) bool {
        return c.class_addProtocol(@ptrCast(self), @ptrCast(protocol)) == c.YES;
    }

    pub fn conformsToProtocol(self: *Class, protocol: *Protocol) bool {
        return c.class_conformsToProtocol(@ptrCast(self), @ptrCast(protocol)) == c.YES;
    }

    /// Only works between `allocateClassPair` and `registerClassPair`. `alignment` is log2 of the alignment in bytes.
    pub fn addIvar(self: *Class, ivar_name: [:0]const u8, size: usize, alignment: u8, types: [:0]const u8) bool {
        return c.class_addIvar(@ptrCast(self), ivar_name, size, alignment, types) == c.YES;
    }

    pub fn getInstanceVariable(self: *Class, ivar_name: [:0]const u8) ?*Ivar {
        return @ptrCast(c.class_getInstanceVariable(@ptrCast(self), ivar_name));
    }

    pub fn getInstanceMethod(self: *Class, sel: *Sel) ?*Method {
        return @ptrCast(c.class_getInstanceMethod(@ptrCast(self), @ptrCast(sel)));
    }

    pub fn getProperty(self: *Class, property_name: [:0]const u8) ?*Property {
        return @ptrCast(c.class_getProperty(@ptrCast(self), property_name));
    }

    /// Only lists properties declared by this class, not its superclasses. Returns null if there are none.
    /// The returned slice is allocated with `malloc` and must be freed with `std.c.free(@ptrCast(list.ptr))`.
    pub fn copyPropertyList(self: *Class) ?[]*Property {
        var count: c_uint = 0;
        const list: [*]*Property = @ptrCast(c.class_copyPropertyList(@ptrCast(self), &count) orelse return null);
        return list[0..count];
    }

    /// Only lists protocols adopted by this class, not its superclasses. Returns null if there are none.
    /// The returned slice is allocated with `malloc` and must be freed with `std.c.free(@ptrCast(list.ptr))`.
    pub fn copyProtocolList(self: *Class) ?[]*Protocol {
        var count: c_uint = 0;
        const list: [*]*Protocol = @ptrCast(c.class_copyProtocolList(@ptrCast(self), &count) orelse return null);
        return list[0..count];
    }
};

test "Class" {
    const rt = @import("root.zig");
    const NSObject = rt.getClass("NSObject").?;
    const NSString = rt.getClass("NSString").?;

    try std.testing.expectEqualStrings("NSString", NSString.getName());
    try std.testing.expectEqual(NSObject, NSString.getSuperclass().?);
    try std.testing.expectEqual(null, NSObject.getSuperclass());
    try std.testing.expect(!NSObject.isMetaClass());
    // An NSObject instance only holds its isa pointer.
    try std.testing.expectEqual(@sizeOf(*anyopaque), NSObject.getInstanceSize());
    try std.testing.expect(NSString.respondsToSelector(Sel.registerName("length")));
    try std.testing.expect(!NSObject.respondsToSelector(Sel.registerName("length")));
    try std.testing.expect(NSString.conformsToProtocol(rt.getProtocol("NSCopying").?));
    try std.testing.expect(!NSObject.conformsToProtocol(rt.getProtocol("NSCopying").?));
    try std.testing.expectEqualStrings("length", NSString.getProperty("length").?.getName());
    try std.testing.expectEqual(null, NSString.getProperty("noSuchProperty"));

    const properties = NSString.copyPropertyList().?;
    defer std.c.free(@ptrCast(properties.ptr));
    for (properties) |property| {
        if (std.mem.eql(u8, property.getName(), "length")) break;
    } else return error.TestExpectedPropertyLength;

    const protocols = NSString.copyProtocolList().?;
    defer std.c.free(@ptrCast(protocols.ptr));
    for (protocols) |protocol| {
        if (protocol.isEqual(rt.getProtocol("NSCopying").?)) break;
    } else return error.TestExpectedProtocolNSCopying;
}

test "Class: addMethod / replaceMethod / addProtocol" {
    const rt = @import("root.zig");
    const Sub = rt.allocateClassPair(rt.getClass("NSObject").?, "NativeObjcClassTest", 0).?;
    const answer = struct {
        fn f(_: *rt.Object, _: *Sel) callconv(.c) usize {
            return 42;
        }
    }.f;
    const seven = struct {
        fn f(_: *rt.Object, _: *Sel) callconv(.c) usize {
            return 7;
        }
    }.f;
    try std.testing.expect(Sub.addMethod(Sel.registerName("answer"), &answer, "Q@:"));
    try std.testing.expect(!Sub.addMethod(Sel.registerName("answer"), &answer, "Q@:"));
    try std.testing.expect(Sub.addProtocol(rt.getProtocol("NSCopying").?));
    rt.registerClassPair(Sub);
    defer rt.disposeClassPair(Sub);

    try std.testing.expect(Sub.respondsToSelector(Sel.registerName("answer")));
    try std.testing.expect(Sub.conformsToProtocol(rt.getProtocol("NSCopying").?));

    const obj = rt.msgSend(Sub, ?*rt.Object, Sel.registerName("new"), .{}).?;
    defer rt.release(obj);
    try std.testing.expectEqual(42, rt.msgSend(obj, usize, Sel.registerName("answer"), .{}));
    try std.testing.expect(Sub.getInstanceMethod(Sel.registerName("answer")) != null);
    try std.testing.expectEqual(null, Sub.getInstanceMethod(Sel.registerName("noSuchMethod")));

    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&answer)), Sub.replaceMethod(Sel.registerName("answer"), &seven, "Q@:"));
    try std.testing.expectEqual(7, rt.msgSend(obj, usize, Sel.registerName("answer"), .{}));
    try std.testing.expectEqual(null, Sub.replaceMethod(Sel.registerName("added"), &seven, "Q@:"));
    try std.testing.expectEqual(7, rt.msgSend(obj, usize, Sel.registerName("added"), .{}));
}

test "Class: addIvar / getInstanceVariable" {
    const rt = @import("root.zig");
    const Sub = rt.allocateClassPair(rt.getClass("NSObject").?, "NativeObjcIvarTest", 0).?;
    const pointer_align_log2 = std.math.log2_int(usize, @alignOf(*anyopaque));
    try std.testing.expect(Sub.addIvar("_value", @sizeOf(*anyopaque), pointer_align_log2, "@"));
    try std.testing.expect(!Sub.addIvar("_value", @sizeOf(*anyopaque), pointer_align_log2, "@"));
    rt.registerClassPair(Sub);
    defer rt.disposeClassPair(Sub);

    try std.testing.expect(!Sub.addIvar("_late", @sizeOf(*anyopaque), pointer_align_log2, "@"));
    try std.testing.expectEqual(2 * @sizeOf(*anyopaque), Sub.getInstanceSize());
    try std.testing.expectEqual(null, Sub.copyPropertyList());
    try std.testing.expectEqual(null, Sub.copyProtocolList());
    try std.testing.expect(Sub.getInstanceVariable("_value") != null);
    try std.testing.expectEqual(null, Sub.getInstanceVariable("_late"));
}
