const std = @import("std");
const c = @import("../c.zig").c;
const Class = @import("Class.zig").Class;
const Ivar = @import("Ivar.zig").Ivar;

pub const Object = opaque {
    pub fn class(self: *Object) *Class {
        return @ptrCast(c.object_getClass(@ptrCast(self)).?);
    }

    pub fn className(self: *Object) [:0]const u8 {
        return std.mem.span(c.object_getClassName(@ptrCast(self)));
    }

    pub fn isClass(self: *Object) bool {
        return c.object_isClass(@ptrCast(self)) == c.YES;
    }

    /// Copies the first `size` bytes of the object, usually `class().instanceSize()`.
    pub fn copy(self: *Object, size: usize) ?*Object {
        return @ptrCast(c.object_copy(@ptrCast(self), size));
    }

    /// Frees the object without sending it `dealloc`.
    pub fn dispose(self: *Object) void {
        _ = c.object_dispose(@ptrCast(self));
    }

    /// If `out_value` is not null, it receives the ivar's current value.
    pub fn instanceVariable(self: *Object, name: [:0]const u8, out_value: ?*?*anyopaque) ?*Ivar {
        return @ptrCast(c.object_getInstanceVariable(@ptrCast(self), name, out_value));
    }

    pub fn ivar(self: *Object, ivar_handle: *Ivar) ?*Object {
        return @ptrCast(c.object_getIvar(@ptrCast(self), @ptrCast(ivar_handle)));
    }

    /// Ivars whose memory management is unknown (e.g. added with `Class.addIvar`) are assigned without retaining.
    pub fn setIvar(self: *Object, ivar_handle: *Ivar, value: ?*Object) void {
        c.object_setIvar(@ptrCast(self), @ptrCast(ivar_handle), @ptrCast(value));
    }
};

test "Object" {
    const objc = @import("root.zig");
    const NSObject = objc.class("NSObject").?;
    const obj = objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);

    try std.testing.expectEqual(NSObject, obj.class());
    try std.testing.expectEqualStrings("NSObject", obj.className());
    try std.testing.expect(!obj.isClass());
    try std.testing.expect(objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("class"), .{}).?.isClass());
}

test "Object: NSNumber class inspection" {
    const objc = @import("root.zig");
    const NSNumber = objc.class("NSNumber").?;
    const allocated = objc.msgSend(NSNumber, ?*Object, objc.Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, objc.Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);

    try std.testing.expectEqualStrings(number.class().name(), number.className());
    try std.testing.expect(!number.isClass());
}

test "Object: ivar / setIvar / instanceVariable / copy / dispose" {
    const objc = @import("root.zig");
    const NSObject = objc.class("NSObject").?;
    const Sub = objc.allocateClassPair(NSObject, "NativeObjcObjectIvarTest", 0).?;
    try std.testing.expect(Sub.addIvar("_value", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "@"));
    objc.registerClassPair(Sub);
    defer objc.disposeClassPair(Sub);

    const obj = objc.msgSend(Sub, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const value = objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(value);

    const ivar = Sub.instanceVariable("_value").?;
    try std.testing.expectEqual(null, obj.ivar(ivar));
    obj.setIvar(ivar, value);
    try std.testing.expectEqual(value, obj.ivar(ivar).?);

    var raw: ?*anyopaque = null;
    try std.testing.expectEqual(ivar, obj.instanceVariable("_value", &raw).?);
    try std.testing.expectEqual(@as(?*anyopaque, value), raw);
    try std.testing.expectEqual(ivar, obj.instanceVariable("_value", null).?);
    try std.testing.expectEqual(null, obj.instanceVariable("_missing", null));

    const copied = obj.copy(Sub.instanceSize()).?;
    try std.testing.expect(copied != obj);
    try std.testing.expectEqual(Sub, copied.class());
    try std.testing.expectEqual(value, copied.ivar(ivar).?);
    copied.dispose();

    const allocated = objc.msgSend(objc.class("NSNumber").?, ?*Object, objc.Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, objc.Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);
    obj.setIvar(ivar, number);
    try std.testing.expectEqual(number, obj.ivar(ivar).?);
    try std.testing.expectEqual(ivar, obj.instanceVariable("_value", &raw).?);
    try std.testing.expectEqual(@as(?*anyopaque, number), raw);

    obj.setIvar(ivar, null);
}
