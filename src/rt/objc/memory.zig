const c = @import("../../c.zig").c;
const Object = @import("../Object.zig").Object;

pub fn retain(obj: *Object) *Object {
    // Tagged pointers need the runtime call without an alignment cast to imported `id`.
    const f: *const fn (*Object) callconv(.c) *Object = @ptrCast(&c.objc_retain);
    return f(obj);
}

pub fn release(obj: *Object) void {
    const f: *const fn (*Object) callconv(.c) void = @ptrCast(&c.objc_release);
    f(obj);
}

pub fn autoreleasePoolPush() *anyopaque {
    return c.objc_autoreleasePoolPush().?;
}

pub fn autoreleasePoolPop(pool: *anyopaque) void {
    c.objc_autoreleasePoolPop(pool);
}
