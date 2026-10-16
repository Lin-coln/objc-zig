const std = @import("std");
const objc = @import("objc").rt;

test "runtime: registered class stores an object through Zig methods" {
    const Object = objc.Object;
    const Sel = objc.Sel;

    const methods = struct {
        fn setPayload(self: *Object, _: *Sel, value: ?*Object) callconv(.c) void {
            const ivar = self.getClass().getInstanceVariable("_payload").?;
            self.setIvar(ivar, value);
        }

        fn getPayload(self: *Object, _: *Sel) callconv(.c) ?*Object {
            const ivar = self.getClass().getInstanceVariable("_payload").?;
            return self.getIvar(ivar);
        }
    };

    const NSObject = objc.getClass("NSObject").?;
    const cls = objc.allocateClassPair(NSObject, "ObjcZigBasicRuntimeFlowTest", 0) orelse return error.ClassAllocFailed;
    try std.testing.expect(cls.addIvar("_payload", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "@"));
    try std.testing.expect(cls.addMethod(Sel.registerName("setPayload:"), &methods.setPayload, "v@:@"));
    try std.testing.expect(cls.addMethod(Sel.registerName("payload"), &methods.getPayload, "@@:"));
    objc.registerClassPair(cls);
    defer objc.disposeClassPair(cls);

    try std.testing.expectEqual(cls, objc.getClass("ObjcZigBasicRuntimeFlowTest").?);

    // Keep the payload alive until after the instance is released.
    const payload = objc.msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(payload);
    const instance = objc.msgSend(cls, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(instance);

    try std.testing.expectEqual(null, objc.msgSend(instance, ?*Object, Sel.registerName("payload"), .{}));
    objc.msgSend(instance, void, Sel.registerName("setPayload:"), .{@as(?*Object, payload)});
    try std.testing.expectEqual(payload, objc.msgSend(instance, ?*Object, Sel.registerName("payload"), .{}).?);
}
