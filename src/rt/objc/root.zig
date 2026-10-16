const std = @import("std");
const c = @import("../../c.zig").c;
const Class = @import("../Class.zig").Class;
const Object = @import("../Object.zig").Object;
const Sel = @import("../Sel.zig").Sel;

const message = @import("message.zig");
const registry = @import("registry.zig");
const object = @import("object.zig");
const memory = @import("memory.zig");

pub const msgSend = message.msgSend;
pub const msgSendSuper = message.msgSendSuper;

pub const class = registry.class;
pub const metaClass = registry.metaClass;
pub const allocateClassPair = registry.allocateClassPair;
pub const registerClassPair = registry.registerClassPair;
pub const disposeClassPair = registry.disposeClassPair;
pub const protocol = registry.protocol;

pub const AssociationPolicy = object.AssociationPolicy;
pub const setAssociatedObject = object.setAssociatedObject;
pub const associatedObject = object.associatedObject;
pub const enumerationMutation = object.enumerationMutation;
pub const setEnumerationMutationHandler = object.setEnumerationMutationHandler;

pub const retain = memory.retain;
pub const release = memory.release;
pub const autoreleasePoolPush = memory.autoreleasePoolPush;
pub const autoreleasePoolPop = memory.autoreleasePoolPop;

test "msgSend / msgSendSuper: class and instance targets, arguments, integer and large struct returns" {
    const objc = @import("../root.zig");
    const Big = extern struct { x: u64, y: u64, z: u64 };
    const impl = struct {
        fn hash(_: *objc.Object, _: c.SEL) callconv(.c) usize {
            return 42;
        }
        fn big(_: *objc.Object, _: c.SEL, x: u64) callconv(.c) Big {
            return .{ .x = x, .y = x + 1, .z = x + 2 };
        }
    };
    const NSObject = class("NSObject").?;
    const Sub = allocateClassPair(NSObject, "NativeObjcMsgSendTest", 0).?;
    try std.testing.expect(Sub.addMethod(objc.Sel.registerName("hash"), &impl.hash, "Q@:"));
    try std.testing.expect(Sub.addMethod(objc.Sel.registerName("big:"), &impl.big, "{Big=QQQ}@:Q"));
    registerClassPair(Sub);
    defer disposeClassPair(Sub);

    const obj = msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);

    try std.testing.expectEqual(42, msgSend(obj, usize, Sel.registerName("hash"), .{}));
    // NSObject's -hash returns the object's address.
    try std.testing.expectEqual(@intFromPtr(obj), msgSendSuper(obj, NSObject, usize, Sel.registerName("hash"), .{}));
    try std.testing.expectEqual(Big{ .x = 7, .y = 8, .z = 9 }, msgSend(obj, Big, Sel.registerName("big:"), .{@as(u64, 7)}));
}

test "class / metaClass / retain / release / autoreleasePool" {
    try std.testing.expectEqual(null, class("NoSuchClassInThisProcess"));
    const meta = metaClass("NSString").?;
    try std.testing.expect(meta.isMetaClass());
    try std.testing.expectEqualStrings("NSString", meta.name());

    const obj = msgSend(class("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);

    try std.testing.expectEqual(obj, retain(obj));
    try std.testing.expectEqual(2, msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
    release(obj);

    const pool = autoreleasePoolPush();
    _ = msgSend(retain(obj), ?*Object, Sel.registerName("autorelease"), .{});
    try std.testing.expectEqual(2, msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
    autoreleasePoolPop(pool);
    try std.testing.expectEqual(1, msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
}

test "NSNumber: msgSendSuper, retain / release, and associated objects" {
    const NSNumber = class("NSNumber").?;
    const allocated = msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer release(number);
    try std.testing.expectEqual(number, retain(number));
    release(number);
    try std.testing.expectEqual(42, msgSend(number, isize, Sel.registerName("integerValue"), .{}));
    try std.testing.expectEqual(number.class(), msgSendSuper(number, class("NSObject").?, *Class, Sel.registerName("class"), .{}));

    const obj = msgSend(class("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);
    const keys = struct {
        var receiver: u8 = 0;
        var value: u8 = 0;
    };

    setAssociatedObject(number, &keys.receiver, obj, .retain_nonatomic);
    defer setAssociatedObject(number, &keys.receiver, null, .retain_nonatomic);
    try std.testing.expectEqual(obj, associatedObject(number, &keys.receiver).?);

    setAssociatedObject(obj, &keys.value, number, .retain_nonatomic);
    defer setAssociatedObject(obj, &keys.value, null, .retain_nonatomic);
    try std.testing.expectEqual(number, associatedObject(obj, &keys.value).?);
}

test "setAssociatedObject / associatedObject" {
    const key = struct {
        var value: u8 = 0;
    };
    const NSObject = class("NSObject").?;
    const obj = msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);
    const value = msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(value);

    try std.testing.expectEqual(null, associatedObject(obj, &key.value));
    setAssociatedObject(obj, &key.value, value, .retain);
    try std.testing.expectEqual(2, msgSend(value, usize, Sel.registerName("retainCount"), .{}));
    {
        // With an atomic policy the getter returns the value retained and autoreleased.
        const pool = autoreleasePoolPush();
        defer autoreleasePoolPop(pool);
        try std.testing.expectEqual(value, associatedObject(obj, &key.value).?);
    }
    try std.testing.expectEqual(2, msgSend(value, usize, Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, null, .retain);
    try std.testing.expectEqual(null, associatedObject(obj, &key.value));
    try std.testing.expectEqual(1, msgSend(value, usize, Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, value, .assign);
    try std.testing.expectEqual(1, msgSend(value, usize, Sel.registerName("retainCount"), .{}));
    setAssociatedObject(obj, &key.value, null, .assign);
}

test "enumerationMutation / setEnumerationMutationHandler" {
    const handler = struct {
        var mutated: ?*Object = null;
        fn f(obj: *Object) callconv(.c) void {
            mutated = obj;
        }
    };
    const obj = msgSend(class("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);

    setEnumerationMutationHandler(&handler.f);
    defer setEnumerationMutationHandler(null);
    enumerationMutation(obj);
    try std.testing.expectEqual(obj, handler.mutated.?);

    const NSNumber = class("NSNumber").?;
    const allocated = msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer release(number);
    enumerationMutation(number);
    try std.testing.expectEqual(number, handler.mutated.?);
}

test "allocateClassPair / registerClassPair / disposeClassPair" {
    const NSObject = class("NSObject").?;
    try std.testing.expectEqual(null, allocateClassPair(NSObject, "NSObject", 0));

    const Sub = allocateClassPair(NSObject, "NativeObjcRootTest", 0).?;
    try std.testing.expectEqual(null, class("NativeObjcRootTest"));
    registerClassPair(Sub);
    try std.testing.expectEqual(Sub, class("NativeObjcRootTest").?);
    try std.testing.expectEqual(NSObject, Sub.superclass().?);
    disposeClassPair(Sub);
    try std.testing.expectEqual(null, class("NativeObjcRootTest"));
}
