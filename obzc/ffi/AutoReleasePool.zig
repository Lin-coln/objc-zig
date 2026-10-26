const std = @import("std");
const c = @import("c.zig").c;

pub const AutoReleasePool = opaque {
    const Self = @This();

    pub fn create() *Self {
        return @ptrCast(c.objc_autoreleasePoolPush().?);
    }

    pub fn release(self: *Self) void {
        c.objc_autoreleasePoolPop(self);
    }
};

test "AutoReleasePool.create: returns a pool token accepted by the runtime" {
    const pool = AutoReleasePool.create();
    defer c.objc_autoreleasePoolPop(pool);
}

test "AutoReleasePool.release: pops the supplied pool token" {
    const Probe = struct {
        var destroyed = false;

        fn dealloc(self: c.id, sel: c.SEL) callconv(.c) void {
            destroyed = true;
            var super: c.struct_objc_super = .{
                .receiver = self,
                .super_class = c.objc_getClass("NSObject"),
            };
            const send: *const fn (*c.struct_objc_super, c.SEL) callconv(.c) void = @ptrCast(&c.objc_msgSendSuper);
            send(&super, sel);
        }
    };
    const cls = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcFfiPoolReleaseProbe", 0) orelse return error.ClassAllocFailed;
    defer c.objc_disposeClassPair(cls);
    try std.testing.expect(c.class_addMethod(cls, c.sel_registerName("dealloc"), @ptrCast(&Probe.dealloc), "v@:") == c.YES);
    c.objc_registerClassPair(cls);

    Probe.destroyed = false;
    const token = c.objc_autoreleasePoolPush().?;
    defer if (!Probe.destroyed) c.objc_autoreleasePoolPop(token);
    const new: *const fn (c.Class, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
    const autorelease: *const fn (c.id, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
    const object = new(cls, c.sel_registerName("new")).?;
    _ = autorelease(object, c.sel_registerName("autorelease"));

    const pool: *AutoReleasePool = @ptrCast(token);
    pool.release();
    try std.testing.expect(Probe.destroyed);
}
