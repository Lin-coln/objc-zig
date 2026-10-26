const std = @import("std");
const objc = @import("root.zig");
const Sel = @import("../Sel.zig").Sel;
const c = @import("../../../ffi/root.zig").c;
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

test "getAssociatedObject: missing keys and NSNumber receivers and values" {
    const NSNumber = objc.getClass("NSNumber").?;
    const allocated = objc.msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);
    const obj = objc.msgSend(objc.getClass("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const keys = struct {
        var receiver: u8 = 0;
        var value: u8 = 0;
    };

    try std.testing.expectEqual(null, getAssociatedObject(obj, &keys.value));
    setAssociatedObject(number, &keys.receiver, obj, .retain_nonatomic);
    defer setAssociatedObject(number, &keys.receiver, null, .retain_nonatomic);
    try std.testing.expectEqual(obj, getAssociatedObject(number, &keys.receiver).?);

    setAssociatedObject(obj, &keys.value, number, .retain_nonatomic);
    defer setAssociatedObject(obj, &keys.value, null, .retain_nonatomic);
    try std.testing.expectEqual(number, getAssociatedObject(obj, &keys.value).?);
}

test "setAssociatedObject: retain, replacement and removal balance ownership" {
    const key = struct {
        var value: u8 = 0;
    };
    const Probe = struct {
        var deallocations: usize = 0;

        fn dealloc(self: *Object, sel: *Sel) callconv(.c) void {
            deallocations += 1;
            objc.msgSendSuper(self, objc.getClass("NSObject").?, void, sel, .{});
        }
    };
    const NSObject = objc.getClass("NSObject").?;
    const Sub = objc.allocateClassPair(NSObject, "ObjcZigAssociatedObjectRetainTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addMethod(Sel.registerName("dealloc"), &Probe.dealloc, "v@:"));
    objc.registerClassPair(Sub);
    const new = Sel.registerName("new");
    const obj = objc.msgSend(NSObject, ?*Object, new, .{}).?;
    defer objc.release(obj);
    const value = objc.msgSend(Sub, ?*Object, new, .{}).?;

    setAssociatedObject(obj, &key.value, value, .retain);
    objc.release(value);
    try std.testing.expectEqual(0, Probe.deallocations);
    {
        // Atomic getters autorelease the value; drain this ownership before replacing it.
        const pool = objc.autoreleasePoolPush();
        defer objc.autoreleasePoolPop(pool);
        try std.testing.expectEqual(value, getAssociatedObject(obj, &key.value).?);
    }
    try std.testing.expectEqual(0, Probe.deallocations);

    const replacement = objc.msgSend(Sub, ?*Object, new, .{}).?;
    setAssociatedObject(obj, &key.value, replacement, .retain_nonatomic);
    objc.release(replacement);
    try std.testing.expectEqual(1, Probe.deallocations);
    try std.testing.expectEqual(replacement, getAssociatedObject(obj, &key.value).?);

    setAssociatedObject(obj, &key.value, null, .retain);
    try std.testing.expectEqual(null, getAssociatedObject(obj, &key.value));
    try std.testing.expectEqual(2, Probe.deallocations);
}

test "setAssociatedObject: assign does not retain the value" {
    const key = struct {
        var value: u8 = 0;
    };
    const Probe = struct {
        var deallocated = false;

        fn dealloc(self: *Object, sel: *Sel) callconv(.c) void {
            deallocated = true;
            objc.msgSendSuper(self, objc.getClass("NSObject").?, void, sel, .{});
        }
    };
    const NSObject = objc.getClass("NSObject").?;
    const Sub = objc.allocateClassPair(NSObject, "ObjcZigAssociatedObjectAssignTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addMethod(Sel.registerName("dealloc"), &Probe.dealloc, "v@:"));
    objc.registerClassPair(Sub);
    const new = Sel.registerName("new");
    const obj = objc.msgSend(NSObject, ?*Object, new, .{}).?;
    defer objc.release(obj);
    const value = objc.msgSend(Sub, ?*Object, new, .{}).?;
    defer if (!Probe.deallocated) objc.release(value);

    setAssociatedObject(obj, &key.value, value, .assign);
    defer setAssociatedObject(obj, &key.value, null, .assign);
    try std.testing.expectEqual(value, getAssociatedObject(obj, &key.value).?);
    objc.release(value);
    try std.testing.expect(Probe.deallocated);
}

test "setAssociatedObject: copy policies preserve data under independent keys" {
    const keys = struct {
        var atomic: u8 = 0;
        var nonatomic: u8 = 0;
    };
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);
    const obj = objc.msgSend(objc.getClass("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const initial = [_]u8{ 7, 9 };
    const source = objc.msgSend(objc.getClass("NSMutableData").?, ?*Object, Sel.registerName("dataWithBytes:length:"), .{ initial[0..].ptr, @as(usize, initial.len) }).?;

    setAssociatedObject(obj, &keys.atomic, source, .copy);
    setAssociatedObject(obj, &keys.nonatomic, source, .copy_nonatomic);
    objc.msgSend(source, [*]u8, Sel.registerName("mutableBytes"), .{})[0] = 42;

    const atomic = getAssociatedObject(obj, &keys.atomic).?;
    const nonatomic = getAssociatedObject(obj, &keys.nonatomic).?;
    const bytes = Sel.registerName("bytes");
    try std.testing.expectEqualSlices(u8, &initial, objc.msgSend(atomic, [*]const u8, bytes, .{})[0..initial.len]);
    try std.testing.expectEqualSlices(u8, &initial, objc.msgSend(nonatomic, [*]const u8, bytes, .{})[0..initial.len]);
    try std.testing.expectEqualSlices(u8, &.{ 42, 9 }, objc.msgSend(source, [*]const u8, bytes, .{})[0..initial.len]);

    setAssociatedObject(obj, &keys.atomic, null, .copy);
    try std.testing.expectEqual(null, getAssociatedObject(obj, &keys.atomic));
    try std.testing.expectEqual(nonatomic, getAssociatedObject(obj, &keys.nonatomic).?);
}

test "enumerationMutation / setEnumerationMutationHandler: ordinary and NSNumber receivers" {
    const handler = struct {
        var mutated: ?*Object = null;
        fn f(obj: *Object) callconv(.c) void {
            mutated = obj;
        }
    };
    const obj = objc.msgSend(objc.getClass("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);
    const NSNumber = objc.getClass("NSNumber").?;
    const allocated = objc.msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);

    setEnumerationMutationHandler(&handler.f);
    defer setEnumerationMutationHandler(null);
    enumerationMutation(obj);
    try std.testing.expectEqual(obj, handler.mutated.?);
    enumerationMutation(number);
    try std.testing.expectEqual(number, handler.mutated.?);
}
