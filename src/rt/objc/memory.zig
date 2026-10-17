const std = @import("std");
const c = @import("../../c.zig").c;
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

test "retain / release / autoreleasePool" {
    const rt = @import("../root.zig");
    const obj = rt.msgSend(rt.getClass("NSObject").?, ?*Object, rt.Sel.registerName("new"), .{}).?;
    defer release(obj);

    try std.testing.expectEqual(obj, retain(obj));
    try std.testing.expectEqual(2, rt.msgSend(obj, usize, rt.Sel.registerName("retainCount"), .{}));
    release(obj);

    const pool = autoreleasePoolPush();
    _ = rt.msgSend(retain(obj), ?*Object, rt.Sel.registerName("autorelease"), .{});
    try std.testing.expectEqual(2, rt.msgSend(obj, usize, rt.Sel.registerName("retainCount"), .{}));
    autoreleasePoolPop(pool);
    try std.testing.expectEqual(1, rt.msgSend(obj, usize, rt.Sel.registerName("retainCount"), .{}));
}

test "NSNumber: retain and release leave the object usable" {
    const rt = @import("../root.zig");
    const NSNumber = rt.getClass("NSNumber").?;
    const allocated = rt.msgSend(NSNumber, ?*Object, rt.Sel.registerName("alloc"), .{}).?;
    const number = rt.msgSend(allocated, ?*Object, rt.Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer release(number);

    try std.testing.expectEqual(number, retain(number));
    release(number);
    try std.testing.expectEqual(42, rt.msgSend(number, isize, rt.Sel.registerName("integerValue"), .{}));
}
