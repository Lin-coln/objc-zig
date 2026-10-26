const std = @import("std");
const ffi = @import("../ffi/root.zig");
const utils = @import("../utils/root.zig");

pub fn Class(comptime T: type) type {
    const class_name = comptime utils.resolveTypeName(@typeName(T));

    return struct {
        pub const m = @import("method/root.zig").method(T, call);

        pub const alloc = m.of("alloc", fn () *T);
        pub const new = m.of("new", fn () *T);

        /// Calls a class method, converting top-level bool arguments and returns through BOOL.
        pub fn call(comptime Return: type, name: [:0]const u8, args: anytype) Return {
            return @import("call.zig").call(getClass(), Return, name, args);
        }

        fn getClass() *ffi.Class {
            return ffi.Class.lookup(class_name).?;
        }
    };
}

test "helpers.Class: getClass resolves the wrapper type" {
    const NSObject = opaque {};
    const NSNumber = opaque {};
    try std.testing.expectEqual(ffi.Class.lookup("NSObject").?, Class(NSObject).getClass());
    try std.testing.expectEqual(ffi.Class.lookup("NSNumber").?, Class(NSNumber).getClass());
}

test "helpers.Class: call binds the receiver to its wrapper class" {
    const NSObject = opaque {};
    const NSNumber = opaque {};

    const object_class = Class(NSObject);
    const number_class = Class(NSNumber);
    try std.testing.expectEqual(ffi.Class.lookup("NSObject").?, object_class.call(*ffi.Class, "class", .{}));
    try std.testing.expectEqual(ffi.Class.lookup("NSNumber").?, number_class.call(*ffi.Class, "class", .{}));
    try std.testing.expectEqual(ffi.Class.lookup("NSObject").?, object_class.call(*ffi.Class, "class", .{}));
}

test "helpers.Class: alloc and new bind their selectors and wrapper class" {
    const ObzcHelpers2ClassConstructionProbe = opaque {};
    const Probe = struct {
        var receiver: ?*ffi.Class = null;
        var selector: ?*ffi.Sel = null;
        var alloc_result: u8 = 0;
        var new_result: u8 = 0;

        fn alloc(cls: *ffi.Class, sel: *ffi.Sel) callconv(.c) *ObzcHelpers2ClassConstructionProbe {
            receiver = cls;
            selector = sel;
            return @ptrCast(&alloc_result);
        }

        fn new(cls: *ffi.Class, sel: *ffi.Sel) callconv(.c) *ObzcHelpers2ClassConstructionProbe {
            receiver = cls;
            selector = sel;
            return @ptrCast(&new_result);
        }
    };
    const cls = ffi.c.objc_allocateClassPair(@ptrCast(ffi.Class.lookup("NSObject").?), "ObzcHelpers2ClassConstructionProbe", 0) orelse return error.ClassAllocFailed;
    defer ffi.c.objc_disposeClassPair(cls);
    ffi.c.objc_registerClassPair(cls);
    const meta = ffi.c.object_getClass(@ptrCast(cls)).?;
    try std.testing.expect(ffi.c.class_addMethod(meta, @ptrCast(ffi.Sel.get("alloc")), @ptrCast(&Probe.alloc), "@@:") == ffi.c.YES);
    try std.testing.expect(ffi.c.class_addMethod(meta, @ptrCast(ffi.Sel.get("new")), @ptrCast(&Probe.new), "@@:") == ffi.c.YES);

    const h = Class(ObzcHelpers2ClassConstructionProbe);
    try std.testing.expectEqual(@as(*ObzcHelpers2ClassConstructionProbe, @ptrCast(&Probe.alloc_result)), h.alloc());
    try std.testing.expectEqual(@as(*ffi.Class, @ptrCast(cls)), Probe.receiver.?);
    try std.testing.expectEqual(ffi.Sel.get("alloc"), Probe.selector.?);
    try std.testing.expectEqual(@as(*ObzcHelpers2ClassConstructionProbe, @ptrCast(&Probe.new_result)), h.new());
    try std.testing.expectEqual(@as(*ffi.Class, @ptrCast(cls)), Probe.receiver.?);
    try std.testing.expectEqual(ffi.Sel.get("new"), Probe.selector.?);
}
