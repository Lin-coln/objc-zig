const std = @import("std");
const objc = @import("root.zig");
const Sel = @import("../Sel.zig").Sel;
const c = @import("../../../ffi/root.zig").c;
const Object = @import("../Object.zig").Object;

pub fn retain(obj: *Object) *Object {
    return @ptrCast(c.objc_retain(@ptrCast(obj)).?);
}

pub fn release(obj: *Object) void {
    c.objc_release(@ptrCast(obj));
}

pub fn autoreleasePoolPush() *anyopaque {
    return c.objc_autoreleasePoolPush().?;
}

pub fn autoreleasePoolPop(pool: *anyopaque) void {
    c.objc_autoreleasePoolPop(pool);
}

test "retain / release: extra ownership keeps the object alive until balanced" {
    const Probe = struct {
        var deallocated = false;

        fn dealloc(self: *Object, sel: *Sel) callconv(.c) void {
            deallocated = true;
            objc.msgSendSuper(self, objc.getClass("NSObject").?, void, sel, .{});
        }
    };
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "ObjcZigRuntimeRetainTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addMethod(Sel.registerName("dealloc"), &Probe.dealloc, "v@:"));
    objc.registerClassPair(Sub);
    const obj = objc.msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    defer if (!Probe.deallocated) release(obj);

    try std.testing.expectEqual(obj, retain(obj));
    release(obj);
    try std.testing.expect(!Probe.deallocated);
    release(obj);
    try std.testing.expect(Probe.deallocated);
}

test "autoreleasePoolPush / autoreleasePoolPop: popping drains deferred releases" {
    const Probe = struct {
        var deallocated = false;

        fn dealloc(self: *Object, sel: *Sel) callconv(.c) void {
            deallocated = true;
            objc.msgSendSuper(self, objc.getClass("NSObject").?, void, sel, .{});
        }
    };
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "ObjcZigRuntimePoolTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addMethod(Sel.registerName("dealloc"), &Probe.dealloc, "v@:"));
    objc.registerClassPair(Sub);
    const obj = objc.msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    {
        const pool = autoreleasePoolPush();
        defer autoreleasePoolPop(pool);
        _ = objc.msgSend(obj, *Object, Sel.registerName("autorelease"), .{});
        try std.testing.expect(!Probe.deallocated);
    }
    try std.testing.expect(Probe.deallocated);
}

test "NSNumber: retain and release leave the object usable" {
    const NSNumber = objc.getClass("NSNumber").?;
    const allocated = objc.msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = objc.msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer release(number);

    try std.testing.expectEqual(number, retain(number));
    release(number);
    try std.testing.expectEqual(42, objc.msgSend(number, isize, Sel.registerName("integerValue"), .{}));
}
