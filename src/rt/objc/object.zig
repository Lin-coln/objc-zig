const std = @import("std");
const c = @import("../../c.zig").c;
const Object = @import("../Object.zig").Object;

pub const AssociationPolicy = enum(usize) {
    assign = c.OBJC_ASSOCIATION_ASSIGN,
    retain_nonatomic = c.OBJC_ASSOCIATION_RETAIN_NONATOMIC,
    copy_nonatomic = c.OBJC_ASSOCIATION_COPY_NONATOMIC,
    retain = c.OBJC_ASSOCIATION_RETAIN,
    copy = c.OBJC_ASSOCIATION_COPY,
};

/// `key` is compared by address, so it is usually the address of a global variable. A null `value` removes the association.
pub fn setAssociatedObject(object: *Object, key: *const anyopaque, value: ?*Object, policy: AssociationPolicy) void {
    c.objc_setAssociatedObject(@ptrCast(object), key, @ptrCast(value), @backingInt(policy));
}

pub fn getAssociatedObject(object: *Object, key: *const anyopaque) ?*Object {
    return @ptrCast(c.objc_getAssociatedObject(@ptrCast(object), key));
}

/// Called when a collection is mutated during fast enumeration. Runs the handler installed with
/// `setEnumerationMutationHandler`; the default one throws an exception.
pub fn enumerationMutation(obj: *Object) void {
    c.objc_enumerationMutation(@ptrCast(obj));
}

/// The handler is process-wide, and the previous one cannot be retrieved.
pub fn setEnumerationMutationHandler(handler: ?*const fn (*Object) callconv(.c) void) void {
    c.objc_setEnumerationMutationHandler(@ptrCast(handler));
}

test "NSNumber: associated objects in both directions" {
    const objc = @import("../root.zig");
    const NSNumber = objc.getClass("NSNumber").?;
    const allocated = objc.msgSend(NSNumber, ?*Object, objc.Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, objc.Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);

    const obj = objc.msgSend(objc.getClass("NSObject").?, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const keys = struct {
        var receiver: u8 = 0;
        var value: u8 = 0;
    };

    setAssociatedObject(number, &keys.receiver, obj, .retain_nonatomic);
    defer setAssociatedObject(number, &keys.receiver, null, .retain_nonatomic);
    try std.testing.expectEqual(obj, getAssociatedObject(number, &keys.receiver).?);

    setAssociatedObject(obj, &keys.value, number, .retain_nonatomic);
    defer setAssociatedObject(obj, &keys.value, null, .retain_nonatomic);
    try std.testing.expectEqual(number, getAssociatedObject(obj, &keys.value).?);
}

test "setAssociatedObject / getAssociatedObject" {
    const objc = @import("../root.zig");
    const key = struct {
        var value: u8 = 0;
    };
    const NSObject = objc.getClass("NSObject").?;
    const obj = objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const value = objc.msgSend(NSObject, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(value);

    try std.testing.expectEqual(null, getAssociatedObject(obj, &key.value));
    setAssociatedObject(obj, &key.value, value, .retain);
    try std.testing.expectEqual(2, objc.msgSend(value, usize, objc.Sel.registerName("retainCount"), .{}));
    {
        // With an atomic policy the getter returns the value retained and autoreleased.
        const pool = objc.autoreleasePoolPush();
        defer objc.autoreleasePoolPop(pool);
        try std.testing.expectEqual(value, getAssociatedObject(obj, &key.value).?);
    }
    try std.testing.expectEqual(2, objc.msgSend(value, usize, objc.Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, null, .retain);
    try std.testing.expectEqual(null, getAssociatedObject(obj, &key.value));
    try std.testing.expectEqual(1, objc.msgSend(value, usize, objc.Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, value, .assign);
    try std.testing.expectEqual(1, objc.msgSend(value, usize, objc.Sel.registerName("retainCount"), .{}));
    setAssociatedObject(obj, &key.value, null, .assign);
}

test "enumerationMutation / setEnumerationMutationHandler" {
    const objc = @import("../root.zig");
    const handler = struct {
        var mutated: ?*Object = null;
        fn f(obj: *Object) callconv(.c) void {
            mutated = obj;
        }
    };
    const obj = objc.msgSend(objc.getClass("NSObject").?, ?*Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);

    setEnumerationMutationHandler(&handler.f);
    defer setEnumerationMutationHandler(null);
    enumerationMutation(obj);
    try std.testing.expectEqual(obj, handler.mutated.?);

    const NSNumber = objc.getClass("NSNumber").?;
    const allocated = objc.msgSend(NSNumber, ?*Object, objc.Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, objc.Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);
    enumerationMutation(number);
    try std.testing.expectEqual(number, handler.mutated.?);
}
