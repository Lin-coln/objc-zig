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
    const rt = @import("root.zig");
    const impl = struct {
        fn one(_: *rt.Object, _: *rt.Sel) callconv(.c) usize {
            return 1;
        }
        fn two(_: *rt.Object, _: *rt.Sel) callconv(.c) usize {
            return 2;
        }
        fn three(_: *rt.Object, _: *rt.Sel) callconv(.c) usize {
            return 3;
        }
    };
    const Sub = rt.allocateClassPair(rt.getClass("NSObject").?, "NativeObjcMethodTest", 0).?;
    try std.testing.expect(Sub.addMethod(rt.Sel.registerName("a"), &impl.one, "Q@:"));
    try std.testing.expect(Sub.addMethod(rt.Sel.registerName("b"), &impl.two, "Q@:"));
    rt.registerClassPair(Sub);
    defer rt.disposeClassPair(Sub);

    const obj = rt.msgSend(Sub, ?*rt.Object, rt.Sel.registerName("new"), .{}).?;
    defer rt.release(obj);

    const a = Sub.getInstanceMethod(rt.Sel.registerName("a")).?;
    const b = Sub.getInstanceMethod(rt.Sel.registerName("b")).?;
    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.one)), a.getImplementation());

    a.exchangeImplementations(b);
    try std.testing.expectEqual(2, rt.msgSend(obj, usize, rt.Sel.registerName("a"), .{}));
    try std.testing.expectEqual(1, rt.msgSend(obj, usize, rt.Sel.registerName("b"), .{}));

    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.two)), a.setImplementation(&impl.three));
    try std.testing.expectEqual(3, rt.msgSend(obj, usize, rt.Sel.registerName("a"), .{}));
}
