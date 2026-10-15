const std = @import("std");
const c = @import("../c.zig").c;
const Class = @import("Class.zig").Class;
const Ivar = @import("Ivar.zig").Ivar;

pub const Object = opaque {
    pub fn getClass(self: *Object) *Class {
        return @ptrCast(c.object_getClass(@ptrCast(@alignCast(self))).?);
    }

    pub fn getClassName(self: *Object) [:0]const u8 {
        return std.mem.span(c.object_getClassName(@ptrCast(@alignCast(self))));
    }

    pub fn isClass(self: *Object) bool {
        return c.object_isClass(@ptrCast(@alignCast(self))) == c.YES;
    }

    /// Copies the first `size` bytes of the object, usually `getClass().getInstanceSize()`.
    pub fn copy(self: *Object, size: usize) ?*Object {
        return @ptrCast(c.object_copy(@ptrCast(@alignCast(self)), size));
    }

    /// Frees the object without sending it `dealloc`.
    pub fn dispose(self: *Object) void {
        _ = c.object_dispose(@ptrCast(@alignCast(self)));
    }

    /// If `out_value` is not null, it receives the ivar's current value.
    pub fn getInstanceVariable(self: *Object, name: [:0]const u8, out_value: ?*?*anyopaque) ?*Ivar {
        return @ptrCast(c.object_getInstanceVariable(@ptrCast(@alignCast(self)), name, out_value));
    }

    pub fn getIvar(self: *Object, ivar: *Ivar) ?*Object {
        return @ptrCast(c.object_getIvar(@ptrCast(@alignCast(self)), @ptrCast(ivar)));
    }

    /// Ivars whose memory management is unknown (e.g. added with `Class.addIvar`) are assigned without retaining.
    pub fn setIvar(self: *Object, ivar: *Ivar, value: ?*Object) void {
        c.object_setIvar(@ptrCast(@alignCast(self)), @ptrCast(ivar), @ptrCast(@alignCast(value)));
    }
};

test "Object" {
    const objc = @import("root.zig");
    const NSObject = objc.getClass("NSObject").?;
    const obj = objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);

    try std.testing.expectEqual(NSObject, obj.getClass());
    try std.testing.expectEqualStrings("NSObject", obj.getClassName());
    try std.testing.expect(!obj.isClass());
    try std.testing.expect(objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("class"), .{}).?.isClass());
}

test "Object: getIvar / setIvar / getInstanceVariable / copy / dispose" {
    const objc = @import("root.zig");
    const NSObject = objc.getClass("NSObject").?;
    const Sub = objc.allocateClassPair(NSObject, "NativeObjcObjectIvarTest", 0).?;
    try std.testing.expect(Sub.addIvar("_value", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "@"));
    objc.registerClassPair(Sub);
    defer objc.disposeClassPair(Sub);

    const obj = objc.msgSend(Sub, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const value = objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(value);

    const ivar = Sub.getInstanceVariable("_value").?;
    try std.testing.expectEqual(null, obj.getIvar(ivar));
    obj.setIvar(ivar, value);
    try std.testing.expectEqual(value, obj.getIvar(ivar).?);

    var raw: ?*anyopaque = null;
    try std.testing.expectEqual(ivar, obj.getInstanceVariable("_value", &raw).?);
    try std.testing.expectEqual(@as(?*anyopaque, value), raw);
    try std.testing.expectEqual(ivar, obj.getInstanceVariable("_value", null).?);
    try std.testing.expectEqual(null, obj.getInstanceVariable("_missing", null));

    const copied = obj.copy(Sub.getInstanceSize()).?;
    try std.testing.expect(copied != obj);
    try std.testing.expectEqual(Sub, copied.getClass());
    try std.testing.expectEqual(value, copied.getIvar(ivar).?);
    copied.dispose();

    obj.setIvar(ivar, null);
}
