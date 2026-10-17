const std = @import("std");
const rt = @import("objc").rt;

test "runtime: registered class stores an object through Zig methods" {
    const Object = rt.Object;
    const Sel = rt.Sel;

    const methods = struct {
        fn setPayload(self: *Object, _: *Sel, value: ?*Object) callconv(.c) void {
            const ivar = self.getClass().getInstanceVariable("_payload").?;
            self.setIvar(ivar, value);
        }

        fn payload(self: *Object, _: *Sel) callconv(.c) ?*Object {
            const ivar = self.getClass().getInstanceVariable("_payload").?;
            return self.getIvar(ivar);
        }
    };

    const NSObject = rt.getClass("NSObject").?;
    const cls = rt.allocateClassPair(NSObject, "ObjcZigBasicRuntimeFlowTest", 0) orelse return error.ClassAllocFailed;
    try std.testing.expect(cls.addIvar("_payload", @sizeOf(*anyopaque), std.math.log2_int(usize, @alignOf(*anyopaque)), "@"));
    try std.testing.expect(cls.addMethod(Sel.registerName("setPayload:"), &methods.setPayload, "v@:@"));
    try std.testing.expect(cls.addMethod(Sel.registerName("payload"), &methods.payload, "@@:"));
    rt.registerClassPair(cls);
    defer rt.disposeClassPair(cls);

    try std.testing.expectEqual(cls, rt.getClass("ObjcZigBasicRuntimeFlowTest").?);

    // Keep the payload alive until after the instance is released.
    const payload = rt.msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer rt.release(payload);
    const instance = rt.msgSend(cls, ?*Object, Sel.registerName("new"), .{}).?;
    defer rt.release(instance);

    try std.testing.expectEqual(null, rt.msgSend(instance, ?*Object, Sel.registerName("payload"), .{}));
    rt.msgSend(instance, void, Sel.registerName("setPayload:"), .{@as(?*Object, payload)});
    try std.testing.expectEqual(payload, rt.msgSend(instance, ?*Object, Sel.registerName("payload"), .{}).?);
}
