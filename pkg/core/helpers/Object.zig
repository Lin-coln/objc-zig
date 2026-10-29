const std = @import("std");
const ffi = @import("../ffi/root.zig");
const c = ffi.c;

pub fn Object(comptime T: type) type {
    return struct {
        const p = @import("prop.zig").prop(T, call);
        pub const m = @import("method/root.zig").method(T, call);
        const i = @import("ivar.zig").ivar(T);

        pub const prop = p.of;
        pub const method = m.of;
        pub const ivar = i.of;

        pub fn call(self: *T, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            return @import("call.zig").call(self, Return, name, args);
        }

        pub fn retain(self: *T) *T {
            return @ptrCast(c.objc_retain(@ptrCast(self)).?);
        }

        pub fn release(self: *T) void {
            c.objc_release(@ptrCast(self));
        }
    };
}

test "helpers.Object.call: forwards the supplied instance instead of binding a class receiver" {
    const Wrapped = opaque {};
    const cls = ffi.Class.lookup("NSObject").?;
    const first = ffi.msg.send(cls, *Wrapped, ffi.Sel.get("new"), .{});
    defer c.objc_release(@ptrCast(first));
    const second = ffi.msg.send(cls, *Wrapped, ffi.Sel.get("new"), .{});
    defer c.objc_release(@ptrCast(second));

    const h = Object(Wrapped);
    try std.testing.expectEqual(first, h.call(first, *Wrapped, "self", .{}));
    try std.testing.expectEqual(second, h.call(second, *Wrapped, "self", .{}));
}

test "helpers.Object.retain: returns the supplied instance with its wrapper type" {
    const Wrapped = opaque {};
    const object = ffi.msg.send(ffi.Class.lookup("NSObject").?, *Wrapped, ffi.Sel.get("new"), .{});
    defer c.objc_release(@ptrCast(object));

    const retained = Object(Wrapped).retain(object);
    defer c.objc_release(@ptrCast(retained));
    try std.testing.expect(@TypeOf(retained) == *Wrapped);
    try std.testing.expectEqual(object, retained);
}

test "helpers.Object.release: releases the supplied instance" {
    const Wrapped = opaque {};
    const Probe = struct {
        var first: ?*Wrapped = null;
        var destroyed: [2]bool = .{ false, false };

        fn dealloc(self: *Wrapped, sel: *ffi.Sel) callconv(.c) void {
            destroyed[if (self == first) @as(usize, 0) else 1] = true;
            ffi.msg.sendSuper(self, ffi.Class.lookup("NSObject").?, void, sel, .{});
        }
    };
    const cls = c.objc_allocateClassPair(@ptrCast(ffi.Class.lookup("NSObject").?), "ObzcHelpers2ObjectOwnership", 0) orelse return error.ClassAllocFailed;
    defer c.objc_disposeClassPair(cls);
    try std.testing.expect(c.class_addMethod(cls, @ptrCast(ffi.Sel.get("dealloc")), @ptrCast(&Probe.dealloc), "v@:") == c.YES);
    c.objc_registerClassPair(cls);

    Probe.destroyed = .{ false, false };
    const first = ffi.msg.send(@as(*ffi.Class, @ptrCast(cls)), *Wrapped, ffi.Sel.get("new"), .{});
    Probe.first = first;
    defer if (!Probe.destroyed[0]) c.objc_release(@ptrCast(first));
    const second = ffi.msg.send(@as(*ffi.Class, @ptrCast(cls)), *Wrapped, ffi.Sel.get("new"), .{});
    defer if (!Probe.destroyed[1]) c.objc_release(@ptrCast(second));

    const h = Object(Wrapped);
    h.release(first);
    try std.testing.expect(Probe.destroyed[0]);
    try std.testing.expect(!Probe.destroyed[1]);
    h.release(second);
    try std.testing.expect(Probe.destroyed[1]);
}
