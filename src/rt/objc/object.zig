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
    const f: *const fn (*Object, *const anyopaque, ?*Object, usize) callconv(.c) void = @ptrCast(&c.objc_setAssociatedObject);
    f(object, key, value, @intFromEnum(policy));
}

pub fn getAssociatedObject(object: *Object, key: *const anyopaque) ?*Object {
    const f: *const fn (*Object, *const anyopaque) callconv(.c) ?*Object = @ptrCast(&c.objc_getAssociatedObject);
    return f(object, key);
}

/// Called when a collection is mutated during fast enumeration. Runs the handler installed with
/// `setEnumerationMutationHandler`; the default one throws an exception.
pub fn enumerationMutation(obj: *Object) void {
    const f: *const fn (*Object) callconv(.c) void = @ptrCast(&c.objc_enumerationMutation);
    f(obj);
}

/// The handler is process-wide, and the previous one cannot be retrieved.
pub fn setEnumerationMutationHandler(handler: ?*const fn (*Object) callconv(.c) void) void {
    c.objc_setEnumerationMutationHandler(@ptrCast(handler));
}
