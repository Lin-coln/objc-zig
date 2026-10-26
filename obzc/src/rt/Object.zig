const std = @import("std");
const objc = @import("objc/root.zig");
const Sel = @import("Sel.zig").Sel;
const c = @import("../../ffi/root.zig").c;
const Class = @import("Class.zig").Class;
const Ivar = @import("Ivar.zig").Ivar;

pub const Object = opaque {
    pub fn getClass(self: *Object) *Class {
        return @ptrCast(c.object_getClass(@ptrCast(self)).?);
    }

    pub fn getClassName(self: *Object) [:0]const u8 {
        return std.mem.span(c.object_getClassName(@ptrCast(self)));
    }

    pub fn isClass(self: *Object) bool {
        return c.object_isClass(@ptrCast(self)) == c.YES;
    }

    /// Copies the first `size` bytes of the object, usually `getClass().getInstanceSize()`.
    pub fn copy(self: *Object, size: usize) ?*Object {
        return @ptrCast(c.object_copy(@ptrCast(self), size));
    }

    /// Frees the object without sending it `dealloc`.
    pub fn dispose(self: *Object) void {
        _ = c.object_dispose(@ptrCast(self));
    }

    /// If `out_value` is not null, it receives the ivar's current value.
    pub fn getInstanceVariable(self: *Object, name: [:0]const u8, out_value: ?*?*anyopaque) ?*Ivar {
        return @ptrCast(c.object_getInstanceVariable(@ptrCast(self), name, out_value));
    }

    /// Sets the named ivar, returning its metadata or null if it does not exist.
    /// Known ownership rules apply; ivars with unknown ownership are assigned without retaining.
    pub fn setInstanceVariable(self: *Object, name: [:0]const u8, value: ?*anyopaque) ?*Ivar {
        return @ptrCast(c.object_setInstanceVariable(@ptrCast(self), name, value));
    }

    pub fn getIvar(self: *Object, ivar_handle: *Ivar) ?*Object {
        return @ptrCast(c.object_getIvar(@ptrCast(self), @ptrCast(ivar_handle)));
    }

    /// Ivars whose memory management is unknown (e.g. added with `Class.addIvar`) are assigned without retaining.
    pub fn setIvar(self: *Object, ivar_handle: *Ivar, value: ?*Object) void {
        c.object_setIvar(@ptrCast(self), @ptrCast(ivar_handle), @ptrCast(value));
    }
};

test "Object: class inspection" {
    const NSObject = objc.getClass("NSObject").?;
    const obj = objc.msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);

    try std.testing.expectEqual(NSObject, obj.getClass());
    try std.testing.expectEqualStrings("NSObject", obj.getClassName());
    try std.testing.expect(!obj.isClass());
    try std.testing.expect(@as(*Object, @ptrCast(NSObject)).isClass());
}

test "Object: NSNumber class inspection" {
    const NSNumber = objc.getClass("NSNumber").?;
    const allocated = objc.msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);

    const class = objc.msgSend(number, *Class, Sel.registerName("class"), .{});
    try std.testing.expectEqual(class, number.getClass());
    try std.testing.expectEqualStrings(class.getName(), number.getClassName());
    try std.testing.expect(!number.isClass());
}

test "Object: setInstanceVariable writes, replaces and clears a named ivar" {
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "NativeObjcObjectContextTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addIvar("_context", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "^v"));
    objc.registerClassPair(Sub);
    const obj = objc.msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const ivar = Sub.getInstanceVariable("_context").?;
    var first: usize = 7;
    var second: usize = 9;
    var raw: ?*anyopaque = null;

    try std.testing.expectEqual(ivar, obj.setInstanceVariable("_context", &first).?);
    _ = obj.getInstanceVariable("_context", &raw);
    try std.testing.expectEqual(@as(?*anyopaque, &first), raw);

    try std.testing.expectEqual(ivar, obj.setInstanceVariable("_context", &second).?);
    _ = obj.getInstanceVariable("_context", &raw);
    try std.testing.expectEqual(@as(?*anyopaque, &second), raw);

    try std.testing.expectEqual(null, obj.setInstanceVariable("_missing", &first));
    _ = obj.getInstanceVariable("_context", &raw);
    try std.testing.expectEqual(@as(?*anyopaque, &second), raw);

    try std.testing.expectEqual(ivar, obj.setInstanceVariable("_context", null).?);
    _ = obj.getInstanceVariable("_context", &raw);
    try std.testing.expectEqual(null, raw);
}

test "Object: getInstanceVariable returns metadata and an optional output value" {
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "NativeObjcObjectLookupTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addIvar("_context", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "^v"));
    objc.registerClassPair(Sub);
    const obj = objc.msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const ivar = Sub.getInstanceVariable("_context").?;
    var context: usize = 7;
    _ = obj.setInstanceVariable("_context", &context);
    var value: ?*anyopaque = null;

    try std.testing.expectEqual(ivar, obj.getInstanceVariable("_context", &value).?);
    try std.testing.expectEqual(@as(?*anyopaque, &context), value);
    try std.testing.expectEqual(ivar, obj.getInstanceVariable("_context", null).?);
    try std.testing.expectEqual(null, obj.getInstanceVariable("_missing", null));
}

test "Object: getIvar and setIvar preserve object, NSNumber and null values" {
    const NSObject = objc.getClass("NSObject").?;
    const Sub = objc.allocateClassPair(NSObject, "NativeObjcObjectIvarTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addIvar("_value", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "@"));
    objc.registerClassPair(Sub);
    const new = Sel.registerName("new");
    const obj = objc.msgSend(Sub, ?*Object, new, .{}).?;
    defer objc.release(obj);
    const ivar = Sub.getInstanceVariable("_value").?;
    const value = objc.msgSend(NSObject, ?*Object, new, .{}).?;
    defer objc.release(value);
    const allocated = objc.msgSend(objc.getClass("NSNumber").?, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);

    try std.testing.expectEqual(null, obj.getIvar(ivar));
    var raw: ?*anyopaque = null;
    for ([_]?*Object{ value, number, null }) |expected| {
        obj.setIvar(ivar, expected);
        try std.testing.expectEqual(expected, obj.getIvar(ivar));
        try std.testing.expectEqual(ivar, obj.getInstanceVariable("_value", &raw).?);
        try std.testing.expectEqual(@as(?*anyopaque, expected), raw);
    }
}

test "Object: copy preserves the class and ivar bytes in a distinct allocation" {
    const NSObject = objc.getClass("NSObject").?;
    const Sub = objc.allocateClassPair(NSObject, "NativeObjcObjectCopyTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addIvar("_value", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "@"));
    objc.registerClassPair(Sub);
    const new = Sel.registerName("new");
    const obj = objc.msgSend(Sub, ?*Object, new, .{}).?;
    defer objc.release(obj);
    const ivar = Sub.getInstanceVariable("_value").?;
    const value = objc.msgSend(NSObject, ?*Object, new, .{}).?;
    defer objc.release(value);
    obj.setIvar(ivar, value);

    const copied = obj.copy(Sub.getInstanceSize()).?;
    defer copied.dispose();
    try std.testing.expect(copied != obj);
    try std.testing.expectEqual(Sub, copied.getClass());
    try std.testing.expectEqual(value, copied.getIvar(ivar).?);
}

test "Object: dispose frees an object without sending dealloc" {
    const Probe = struct {
        var deallocated = false;

        fn dealloc(self: *Object, sel: *Sel) callconv(.c) void {
            deallocated = true;
            objc.msgSendSuper(self, objc.getClass("NSObject").?, void, sel, .{});
        }
    };
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "NativeObjcObjectDisposeTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addMethod(Sel.registerName("dealloc"), &Probe.dealloc, "v@:"));
    objc.registerClassPair(Sub);
    const obj = objc.msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;

    obj.dispose();
    try std.testing.expect(!Probe.deallocated);
}
