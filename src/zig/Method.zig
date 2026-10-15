const std = @import("std");
const c = @import("../c.zig").c;

pub const Method = opaque {
    pub fn getImplementation(self: *Method) c.IMP {
        return c.method_getImplementation(@ptrCast(self));
    }

    /// Returns the previous implementation. `imp` follows the same rules as in `Class.addMethod`.
    pub fn setImplementation(self: *Method, imp: anytype) c.IMP {
        return c.method_setImplementation(@ptrCast(self), @ptrCast(imp));
    }

    pub fn exchangeImplementations(self: *Method, other: *Method) void {
        c.method_exchangeImplementations(@ptrCast(self), @ptrCast(other));
    }
};

test "Method: getImplementation / setImplementation / exchangeImplementations" {
    const objc = @import("root.zig");
    const impl = struct {
        fn one(_: *objc.Object, _: *objc.Sel) callconv(.c) usize {
            return 1;
        }
        fn two(_: *objc.Object, _: *objc.Sel) callconv(.c) usize {
            return 2;
        }
        fn three(_: *objc.Object, _: *objc.Sel) callconv(.c) usize {
            return 3;
        }
    };
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "NativeObjcMethodTest", 0).?;
    try std.testing.expect(Sub.addMethod(objc.Sel.registerName("a"), &impl.one, "Q@:"));
    try std.testing.expect(Sub.addMethod(objc.Sel.registerName("b"), &impl.two, "Q@:"));
    objc.registerClassPair(Sub);
    defer objc.disposeClassPair(Sub);

    const obj = objc.msgSend(Sub, ?*objc.Object, objc.Sel.registerName("new"), .{}).?;
    defer objc.release(obj);

    const a = Sub.getInstanceMethod(objc.Sel.registerName("a")).?;
    const b = Sub.getInstanceMethod(objc.Sel.registerName("b")).?;
    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.one)), a.getImplementation());

    a.exchangeImplementations(b);
    try std.testing.expectEqual(2, objc.msgSend(obj, usize, objc.Sel.registerName("a"), .{}));
    try std.testing.expectEqual(1, objc.msgSend(obj, usize, objc.Sel.registerName("b"), .{}));

    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.two)), a.setImplementation(&impl.three));
    try std.testing.expectEqual(3, objc.msgSend(obj, usize, objc.Sel.registerName("a"), .{}));
}
