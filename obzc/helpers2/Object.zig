const std = @import("std");
const ffi = @import("../ffi/root.zig");
const utils = @import("../utils/root.zig");
const calling = @import("calling.zig");
const c = ffi.c;

pub fn Object(comptime T: type) type {
    const class_name = comptime utils.resolveTypeName(@typeName(T));

    return struct {
        pub fn call(self: *T, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            return calling.call(self, Return, name, args);
        }

        pub fn retain(self: *T) *T {
            return @ptrCast(c.objc_retain(@ptrCast(self)).?);
        }

        pub fn release(self: *T) void {
            c.objc_release(@ptrCast(self));
        }

        pub fn prop(
            comptime name: [:0]const u8,
            comptime P: type,
        ) type {
            return struct {
                pub fn getter(self: *T) P {
                    const cls = ffi.Class.lookup(class_name).?;
                    const get = if (cls.getProperty(name)) |metadata|
                        metadata.copyAttributeValue("G")
                    else
                        null;
                    defer if (get) |custom| std.c.free(custom.ptr);

                    const selector = get orelse name;
                    return call(self, P, selector, .{});
                }
                pub fn setter(self: *T, value: P) void {
                    const set = "set" ++ [_]u8{std.ascii.toUpper(name[0])} ++ name[1..] ++ ":";
                    call(self, void, set, .{value});
                }
            };
        }
    };
}

test "helpers2.Object.call: forwards the supplied instance instead of binding a class receiver" {
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

test "helpers2.Object.retain: returns the supplied instance with its wrapper type" {
    const Wrapped = opaque {};
    const object = ffi.msg.send(ffi.Class.lookup("NSObject").?, *Wrapped, ffi.Sel.get("new"), .{});
    defer c.objc_release(@ptrCast(object));

    const retained = Object(Wrapped).retain(object);
    defer c.objc_release(@ptrCast(retained));
    try std.testing.expect(@TypeOf(retained) == *Wrapped);
    try std.testing.expectEqual(object, retained);
}

test "helpers2.Object.release: releases the supplied instance" {
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

test "helpers2.Object.prop.getter: selects a custom getter or falls back to the property name" {
    const ObzcHelpers2PropertyProbe = opaque {};
    const Methods = struct {
        fn value(_: *ObzcHelpers2PropertyProbe, _: *ffi.Sel) callconv(.c) i64 {
            return 19;
        }
        fn custom(_: *ObzcHelpers2PropertyProbe, _: *ffi.Sel) callconv(.c) i64 {
            return 37;
        }
        fn ordinary(_: *ObzcHelpers2PropertyProbe, _: *ffi.Sel) callconv(.c) i64 {
            return 23;
        }
        fn plain(_: *ObzcHelpers2PropertyProbe, _: *ffi.Sel) callconv(.c) i64 {
            return 11;
        }
    };
    const cls = c.objc_allocateClassPair(@ptrCast(ffi.Class.lookup("NSObject").?), "ObzcHelpers2PropertyProbe", 0) orelse return error.ClassAllocFailed;
    defer c.objc_disposeClassPair(cls);
    try std.testing.expect(c.class_addMethod(cls, @ptrCast(ffi.Sel.get("value")), @ptrCast(&Methods.value), "q@:") == c.YES);
    try std.testing.expect(c.class_addMethod(cls, @ptrCast(ffi.Sel.get("readValue")), @ptrCast(&Methods.custom), "q@:") == c.YES);
    try std.testing.expect(c.class_addMethod(cls, @ptrCast(ffi.Sel.get("ordinary")), @ptrCast(&Methods.ordinary), "q@:") == c.YES);
    try std.testing.expect(c.class_addMethod(cls, @ptrCast(ffi.Sel.get("plain")), @ptrCast(&Methods.plain), "q@:") == c.YES);
    const custom_attributes = [_]c.objc_property_attribute_t{
        .{ .name = "T", .value = "q" },
        .{ .name = "G", .value = "readValue" },
    };
    try std.testing.expect(c.class_addProperty(cls, "value", &custom_attributes, custom_attributes.len) == c.YES);
    const ordinary_attributes = [_]c.objc_property_attribute_t{.{ .name = "T", .value = "q" }};
    try std.testing.expect(c.class_addProperty(cls, "ordinary", &ordinary_attributes, ordinary_attributes.len) == c.YES);
    c.objc_registerClassPair(cls);
    const object = ffi.msg.send(@as(*ffi.Class, @ptrCast(cls)), *ObzcHelpers2PropertyProbe, ffi.Sel.get("new"), .{});
    defer c.objc_release(@ptrCast(object));

    const h = Object(ObzcHelpers2PropertyProbe);
    try std.testing.expectEqual(@as(i64, 37), h.prop("value", i64).getter(object));
    try std.testing.expectEqual(@as(i64, 23), h.prop("ordinary", i64).getter(object));
    try std.testing.expectEqual(@as(i64, 11), h.prop("plain", i64).getter(object));
}

test "helpers2.Object.prop.setter: generates setName and forwards the instance and value" {
    const Wrapped = opaque {};
    const cls = ffi.Class.lookup("NSMutableData").?;
    const first = ffi.msg.send(cls, *Wrapped, ffi.Sel.get("new"), .{});
    defer c.objc_release(@ptrCast(first));
    const second = ffi.msg.send(cls, *Wrapped, ffi.Sel.get("new"), .{});
    defer c.objc_release(@ptrCast(second));

    const length = Object(Wrapped).prop("length", usize);
    length.setter(first, 7);
    try std.testing.expectEqual(7, ffi.msg.send(first, usize, ffi.Sel.get("length"), .{}));
    try std.testing.expectEqual(0, ffi.msg.send(second, usize, ffi.Sel.get("length"), .{}));
    length.setter(second, 12);
    try std.testing.expectEqual(7, ffi.msg.send(first, usize, ffi.Sel.get("length"), .{}));
    try std.testing.expectEqual(12, ffi.msg.send(second, usize, ffi.Sel.get("length"), .{}));
}
