const std = @import("std");
const c = @import("../../c.zig").c;
const Class = @import("../Class.zig").Class;
const Protocol = @import("../Protocol.zig").Protocol;

pub fn getClass(name: [:0]const u8) ?*Class {
    return @ptrCast(c.objc_getClass(name));
}

/// Unlike `getClass`, logs a message to stderr when no class named `name` exists.
pub fn getMetaClass(name: [:0]const u8) ?*Class {
    return @ptrCast(c.objc_getMetaClass(name));
}

/// Returns null if a class named `name` already exists.
pub fn allocateClassPair(superclass: ?*Class, name: [:0]const u8, extra_bytes: usize) ?*Class {
    return @ptrCast(c.objc_allocateClassPair(@ptrCast(superclass), name, extra_bytes));
}

pub fn registerClassPair(cls: *Class) void {
    c.objc_registerClassPair(@ptrCast(cls));
}

/// Must not be called while instances of `cls` or its subclasses exist.
pub fn disposeClassPair(cls: *Class) void {
    c.objc_disposeClassPair(@ptrCast(cls));
}

pub fn getProtocol(name: [:0]const u8) ?*Protocol {
    return @ptrCast(c.objc_getProtocol(name));
}

test "getClass / getMetaClass" {
    try std.testing.expectEqual(null, getClass("NoSuchClassInThisProcess"));
    const meta = getMetaClass("NSString").?;
    try std.testing.expect(meta.isMetaClass());
    try std.testing.expectEqualStrings("NSString", meta.getName());
}

test "allocateClassPair / registerClassPair / disposeClassPair" {
    const NSObject = getClass("NSObject").?;
    try std.testing.expectEqual(null, allocateClassPair(NSObject, "NSObject", 0));

    const Sub = allocateClassPair(NSObject, "NativeObjcRootTest", 0).?;
    try std.testing.expectEqual(null, getClass("NativeObjcRootTest"));
    registerClassPair(Sub);
    try std.testing.expectEqual(Sub, getClass("NativeObjcRootTest").?);
    try std.testing.expectEqual(NSObject, Sub.getSuperclass().?);
    disposeClassPair(Sub);
    try std.testing.expectEqual(null, getClass("NativeObjcRootTest"));
}
