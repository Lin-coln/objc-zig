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
