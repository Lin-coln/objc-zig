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
    const rt = @import("../root.zig");
    const NSNumber = rt.getClass("NSNumber").?;
    const allocated = rt.msgSend(NSNumber, ?*Object, rt.Sel.registerName("alloc"), .{}).?;
    const number = rt.msgSend(allocated, ?*Object, rt.Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer rt.release(number);

    const obj = rt.msgSend(rt.getClass("NSObject").?, ?*Object, rt.Sel.registerName("new"), .{}).?;
    defer rt.release(obj);
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
    const rt = @import("../root.zig");
    const key = struct {
        var value: u8 = 0;
    };
    const NSObject = rt.getClass("NSObject").?;
    const obj = rt.msgSend(NSObject, ?*Object, rt.Sel.registerName("new"), .{}).?;
    defer rt.release(obj);
    const value = rt.msgSend(NSObject, ?*Object, rt.Sel.registerName("new"), .{}).?;
    defer rt.release(value);

    try std.testing.expectEqual(null, getAssociatedObject(obj, &key.value));
    setAssociatedObject(obj, &key.value, value, .retain);
    try std.testing.expectEqual(2, rt.msgSend(value, usize, rt.Sel.registerName("retainCount"), .{}));
    {
        // With an atomic policy the getter returns the value retained and autoreleased.
        const pool = rt.autoreleasePoolPush();
        defer rt.autoreleasePoolPop(pool);
        try std.testing.expectEqual(value, getAssociatedObject(obj, &key.value).?);
    }
    try std.testing.expectEqual(2, rt.msgSend(value, usize, rt.Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, null, .retain);
    try std.testing.expectEqual(null, getAssociatedObject(obj, &key.value));
    try std.testing.expectEqual(1, rt.msgSend(value, usize, rt.Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, value, .assign);
    try std.testing.expectEqual(1, rt.msgSend(value, usize, rt.Sel.registerName("retainCount"), .{}));
    setAssociatedObject(obj, &key.value, null, .assign);
}

test "enumerationMutation / setEnumerationMutationHandler" {
    const rt = @import("../root.zig");
    const handler = struct {
        var mutated: ?*Object = null;
        fn f(obj: *Object) callconv(.c) void {
            mutated = obj;
        }
    };
    const obj = rt.msgSend(rt.getClass("NSObject").?, ?*Object, rt.Sel.registerName("new"), .{}).?;
    defer rt.release(obj);

    setEnumerationMutationHandler(&handler.f);
    defer setEnumerationMutationHandler(null);
    enumerationMutation(obj);
    try std.testing.expectEqual(obj, handler.mutated.?);

    const NSNumber = rt.getClass("NSNumber").?;
    const allocated = rt.msgSend(NSNumber, ?*Object, rt.Sel.registerName("alloc"), .{}).?;
    const number = rt.msgSend(allocated, ?*Object, rt.Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer rt.release(number);
    enumerationMutation(number);
    try std.testing.expectEqual(number, handler.mutated.?);
}
