const std = @import("std");
const ffi = @import("../../ffi/root.zig");
const utils = @import("../../utils/root.zig");
const c = ffi.c;
const Class = ffi.Class;

pub fn ClassFactory(comptime T: type) type {
    const class_name = comptime utils.resolveTypeName(@typeName(T));

    const m = @import("method.zig").method(T);
    const i = @import("ivar.zig").ivar(T);
    return struct {
        pub fn allocate(super: ?[:0]const u8) !*Class {
            const super_class: ?*Class = if (super) |name|
                Class.lookup(name) orelse return error.SuperClassNotFound
            else
                null;

            const allocated = c.objc_allocateClassPair(
                if (super_class) |ptr| @ptrCast(ptr) else null,
                class_name,
                0,
            ) orelse return error.AllocateClassFailed;

            return @ptrCast(allocated);
        }

        pub const addMethod = m.addMethod;
        pub const addStaticMethod = m.addStaticMethod;
        pub const addIvar = i.addIvar;
    };
}

test "ClassFactory.allocate: binds the wrapper name and requested superclass" {
    const ObzcFactoryAllocatedProbe = opaque {};
    const factory = ClassFactory(ObzcFactoryAllocatedProbe);
    const cls = try factory.allocate("NSObject");
    defer c.objc_disposeClassPair(@ptrCast(cls));
    try std.testing.expectEqualStrings("ObzcFactoryAllocatedProbe", std.mem.span(c.class_getName(@ptrCast(cls))));
    try std.testing.expectEqual(@as(c.Class, @ptrCast(c.objc_getClass("NSObject"))), c.class_getSuperclass(@ptrCast(cls)));
    c.objc_registerClassPair(@ptrCast(cls));
    try std.testing.expectError(error.AllocateClassFailed, factory.allocate("NSObject"));
}

test "ClassFactory.allocate: accepts a root class and rejects a missing superclass" {
    const ObzcFactoryRootProbe = opaque {};
    const factory = ClassFactory(ObzcFactoryRootProbe);
    try std.testing.expectError(error.SuperClassNotFound, factory.allocate("ObzcFactoryMissingParent"));
    const cls = try factory.allocate(null);
    defer c.objc_disposeClassPair(@ptrCast(cls));
    try std.testing.expectEqual(null, c.class_getSuperclass(@ptrCast(cls)));
}

test {
    _ = @import("method.zig");
    _ = @import("ivar.zig");
}
