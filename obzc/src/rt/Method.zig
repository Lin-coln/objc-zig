const std = @import("std");
const objc = @import("objc/root.zig");
const Sel = @import("Sel.zig").Sel;
const Object = @import("Object.zig").Object;
const c = @import("../../ffi/root.zig").c;

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

test "Method: getImplementation and setImplementation" {
    const impl = struct {
        fn one(_: *Object, _: *Sel) callconv(.c) usize {
            return 1;
        }
        fn two(_: *Object, _: *Sel) callconv(.c) usize {
            return 2;
        }
    };
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "NativeObjcMethodReplacementTest", 0).?;
    defer objc.disposeClassPair(Sub);
    const answer = Sel.registerName("answer");
    try std.testing.expect(Sub.addMethod(answer, &impl.one, "Q@:"));
    objc.registerClassPair(Sub);
    const method = Sub.getInstanceMethod(answer).?;

    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.one)), method.getImplementation());
    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.one)), method.setImplementation(&impl.two));
    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.two)), method.getImplementation());
}

test "Method: exchangeImplementations swaps both method slots" {
    const impl = struct {
        fn one(_: *Object, _: *Sel) callconv(.c) usize {
            return 1;
        }
        fn two(_: *Object, _: *Sel) callconv(.c) usize {
            return 2;
        }
    };
    const Sub = objc.allocateClassPair(objc.getClass("NSObject").?, "NativeObjcMethodExchangeTest", 0).?;
    defer objc.disposeClassPair(Sub);
    const a_sel = Sel.registerName("a");
    const b_sel = Sel.registerName("b");
    try std.testing.expect(Sub.addMethod(a_sel, &impl.one, "Q@:"));
    try std.testing.expect(Sub.addMethod(b_sel, &impl.two, "Q@:"));
    objc.registerClassPair(Sub);
    const a = Sub.getInstanceMethod(a_sel).?;
    const b = Sub.getInstanceMethod(b_sel).?;

    a.exchangeImplementations(b);
    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.two)), a.getImplementation());
    try std.testing.expectEqual(@as(c.IMP, @ptrCast(&impl.one)), b.getImplementation());
}
