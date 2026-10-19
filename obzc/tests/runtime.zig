const std = @import("std");
const rt = @import("obzc").rt;

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

    // Keep both payloads alive until after the instances are released.
    const first_payload = rt.msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer rt.release(first_payload);
    const second_payload = rt.msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer rt.release(second_payload);
    const first = rt.msgSend(cls, ?*Object, Sel.registerName("new"), .{}).?;
    defer rt.release(first);
    const second = rt.msgSend(cls, ?*Object, Sel.registerName("new"), .{}).?;
    defer rt.release(second);

    const get_payload = Sel.registerName("payload");
    const set_payload = Sel.registerName("setPayload:");
    try std.testing.expectEqual(null, rt.msgSend(first, ?*Object, get_payload, .{}));
    try std.testing.expectEqual(null, rt.msgSend(second, ?*Object, get_payload, .{}));

    rt.msgSend(first, void, set_payload, .{@as(?*Object, first_payload)});
    try std.testing.expectEqual(first_payload, rt.msgSend(first, ?*Object, get_payload, .{}).?);
    try std.testing.expectEqual(null, rt.msgSend(second, ?*Object, get_payload, .{}));

    rt.msgSend(second, void, set_payload, .{@as(?*Object, second_payload)});
    try std.testing.expectEqual(first_payload, rt.msgSend(first, ?*Object, get_payload, .{}).?);
    try std.testing.expectEqual(second_payload, rt.msgSend(second, ?*Object, get_payload, .{}).?);

    rt.msgSend(first, void, set_payload, .{@as(?*Object, null)});
    try std.testing.expectEqual(null, rt.msgSend(first, ?*Object, get_payload, .{}));
    try std.testing.expectEqual(second_payload, rt.msgSend(second, ?*Object, get_payload, .{}).?);
}
