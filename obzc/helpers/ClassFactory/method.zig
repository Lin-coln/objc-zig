const std = @import("std");
const ffi = @import("../../ffi/root.zig");
const Metadata = @import("../../encode/Metadata.zig");
const encodeFunction = @import("../../encode/root.zig").encodeFunction;
const c = ffi.c;
const Sel = ffi.Sel;
const Class = ffi.Class;

pub fn method(comptime T: type) type {
    _ = T;

    return struct {
        pub fn addStaticMethod(
            cls: *Class,
            comptime name: [:0]const u8,
            comptime handler: anytype,
        ) !void {
            const metaclass = cls.metaclass() orelse
                return error.MetaClassNotFound;
            try addMethod(metaclass, name, handler);
        }

        pub fn addMethod(
            cls: *Class,
            comptime name: [:0]const u8,
            comptime handler: anytype,
        ) !void {
            const Fn = @TypeOf(handler);
            const imp: c.IMP = @ptrCast(&handler);

            const done = c.class_addMethod(
                @ptrCast(cls),
                @ptrCast(Sel.get(name)),
                imp,
                comptime encodeFunction(Fn, ""),
            );
            if (done == c.YES) return;
            return error.AddMethodFailed;
        }
    };
}

test "ClassFactory.method.addMethod: binds the function to the selector" {
    const T = opaque {
        pub const metadata = Metadata.obj;
    };
    const Probe = struct {
        fn handle(_: *T, _: *Sel) callconv(.c) void {}
    };
    const raw = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcFactoryMethodProbe", 0).?;
    defer c.objc_disposeClassPair(raw);
    c.objc_registerClassPair(raw);
    const cls: *Class = @ptrCast(raw);
    const methods = method(T);
    try methods.addMethod(cls, "first", Probe.handle);
    const metadata = c.class_getInstanceMethod(raw, c.sel_registerName("first")).?;
    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&Probe.handle)), c.method_getImplementation(metadata));
    try std.testing.expectEqualStrings("v@:", std.mem.span(c.method_getTypeEncoding(metadata)));
    try std.testing.expectError(error.AddMethodFailed, methods.addMethod(cls, "first", Probe.handle));
}

test "ClassFactory.method.addStaticMethod: targets the metaclass and propagates duplicate errors" {
    const T = opaque {};
    const Probe = struct {
        fn handle(_: *Class, _: *Sel) callconv(.c) void {}
    };
    const raw = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcFactoryStaticMethodProbe", 0).?;
    defer c.objc_disposeClassPair(raw);
    c.objc_registerClassPair(raw);
    const cls: *Class = @ptrCast(raw);
    const methods = method(T);
    try methods.addStaticMethod(cls, "factoryProbe", Probe.handle);
    const selector = c.sel_registerName("factoryProbe");
    try std.testing.expect(c.class_getClassMethod(raw, selector) != null);
    try std.testing.expectEqual(null, c.class_getInstanceMethod(raw, selector));
    try std.testing.expectEqualStrings("v#:", std.mem.span(c.method_getTypeEncoding(c.class_getClassMethod(raw, selector).?)));
    try std.testing.expectError(error.AddMethodFailed, methods.addStaticMethod(cls, "factoryProbe", Probe.handle));
}
