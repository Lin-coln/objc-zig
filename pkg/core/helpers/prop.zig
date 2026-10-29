const std = @import("std");
const ffi = @import("../ffi/root.zig");
const utils = @import("../utils/root.zig");
const Class = ffi.Class;

pub fn prop(comptime T: type, comptime call: anytype) type {
    const class_name = comptime utils.resolveTypeName(@typeName(T));

    return struct {
        pub fn of(comptime name: [:0]const u8, comptime P: type) type {
            return struct {
                pub fn getter(self: *T) P {
                    return get(self, P, name);
                }
                pub fn setter(self: *T, value: P) void {
                    set(self, P, name, value);
                }
            };
        }

        pub fn get(self: *T, comptime P: type, name: [:0]const u8) P {
            const cls = Class.lookup(class_name).?;
            const getter = if (cls.getProperty(name)) |metadata| metadata.copyAttributeValue("G") else null;
            defer if (getter) |custom| std.c.free(custom.ptr);
            const selector = getter orelse name;
            return call(self, P, selector, .{});
        }

        pub fn set(self: *T, comptime P: type, comptime name: [:0]const u8, value: P) void {
            const setter = "set" ++ [_]u8{std.ascii.toUpper(name[0])} ++ name[1..] ++ ":";
            call(self, void, setter, .{value});
        }
    };
}

test "helpers.prop.get: selects a custom getter or falls back to the property name" {
    const ObzcHelpers2PropGetProbe = opaque {};
    const Recorder = struct {
        var receiver: ?*ObzcHelpers2PropGetProbe = null;
        var selector: [64]u8 = undefined;
        var selector_len: usize = 0;
        var argument_count: usize = 0;
        var returns_i64: bool = false;

        fn call(self: *ObzcHelpers2PropGetProbe, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            receiver = self;
            selector_len = name.len;
            @memcpy(selector[0..name.len], name);
            argument_count = args.len;
            returns_i64 = Return == i64;
            return 37;
        }
    };
    const cls = ffi.c.objc_allocateClassPair(@ptrCast(Class.lookup("NSObject").?), "ObzcHelpers2PropGetProbe", 0) orelse return error.ClassAllocFailed;
    defer ffi.c.objc_disposeClassPair(cls);
    const custom_attributes = [_]ffi.c.objc_property_attribute_t{
        .{ .name = "T", .value = "q" },
        .{ .name = "G", .value = "readValue" },
    };
    try std.testing.expect(ffi.c.class_addProperty(cls, "value", &custom_attributes, custom_attributes.len) == ffi.c.YES);
    const ordinary_attributes = [_]ffi.c.objc_property_attribute_t{.{ .name = "T", .value = "q" }};
    try std.testing.expect(ffi.c.class_addProperty(cls, "ordinary", &ordinary_attributes, ordinary_attributes.len) == ffi.c.YES);
    ffi.c.objc_registerClassPair(cls);

    var context: u8 = 0;
    const receiver: *ObzcHelpers2PropGetProbe = @ptrCast(&context);
    const p = prop(ObzcHelpers2PropGetProbe, Recorder.call);
    inline for (.{ .{ "value", "readValue" }, .{ "ordinary", "ordinary" }, .{ "plain", "plain" } }) |entry| {
        try std.testing.expectEqual(@as(i64, 37), p.get(receiver, i64, entry[0]));
        try std.testing.expectEqualStrings(entry[1], Recorder.selector[0..Recorder.selector_len]);
        try std.testing.expectEqual(receiver, Recorder.receiver.?);
        try std.testing.expectEqual(@as(usize, 0), Recorder.argument_count);
        try std.testing.expect(Recorder.returns_i64);
    }
}

test "helpers.prop.set: generates the setter and forwards the receiver, type and value" {
    const Wrapped = opaque {};
    const Recorder = struct {
        var receiver: ?*Wrapped = null;
        var selector: [64]u8 = undefined;
        var selector_len: usize = 0;
        var value: i64 = 0;
        var argument_count: usize = 0;
        var returns_void: bool = false;
        var takes_i64: bool = false;

        fn call(self: *Wrapped, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            receiver = self;
            selector_len = name.len;
            @memcpy(selector[0..name.len], name);
            value = args[0];
            argument_count = args.len;
            returns_void = Return == void;
            takes_i64 = @TypeOf(args[0]) == i64;
        }
    };
    var first_context: u8 = 0;
    var second_context: u8 = 0;
    const first: *Wrapped = @ptrCast(&first_context);
    const second: *Wrapped = @ptrCast(&second_context);
    const p = prop(Wrapped, Recorder.call);

    p.set(first, i64, "value", -7);
    try std.testing.expectEqualStrings("setValue:", Recorder.selector[0..Recorder.selector_len]);
    try std.testing.expectEqual(first, Recorder.receiver.?);
    try std.testing.expectEqual(@as(i64, -7), Recorder.value);
    try std.testing.expectEqual(@as(usize, 1), Recorder.argument_count);
    try std.testing.expect(Recorder.returns_void and Recorder.takes_i64);

    p.set(second, i64, "URL", 19);
    try std.testing.expectEqualStrings("setURL:", Recorder.selector[0..Recorder.selector_len]);
    try std.testing.expectEqual(second, Recorder.receiver.?);
    try std.testing.expectEqual(@as(i64, 19), Recorder.value);
}

test "helpers.prop.of: binds the property name and type to generated accessors" {
    const NSObject = opaque {};
    const Recorder = struct {
        var receiver: ?*NSObject = null;
        var selector: [64]u8 = undefined;
        var selector_len: usize = 0;
        var value: usize = 0;

        fn call(self: *NSObject, comptime Return: type, name: [:0]const u8, args: anytype) Return {
            receiver = self;
            selector_len = name.len;
            @memcpy(selector[0..name.len], name);
            if (Return == void) {
                value = args[0];
            } else {
                return 41;
            }
        }
    };
    const accessor = prop(NSObject, Recorder.call).of("obzcBoundValue", usize);
    try std.testing.expect(@TypeOf(accessor.getter) == fn (*NSObject) usize);
    try std.testing.expect(@TypeOf(accessor.setter) == fn (*NSObject, usize) void);

    var first_context: u8 = 0;
    var second_context: u8 = 0;
    const first: *NSObject = @ptrCast(&first_context);
    const second: *NSObject = @ptrCast(&second_context);
    try std.testing.expectEqual(@as(usize, 41), accessor.getter(first));
    try std.testing.expectEqualStrings("obzcBoundValue", Recorder.selector[0..Recorder.selector_len]);
    try std.testing.expectEqual(first, Recorder.receiver.?);
    accessor.setter(second, 9);
    try std.testing.expectEqualStrings("setObzcBoundValue:", Recorder.selector[0..Recorder.selector_len]);
    try std.testing.expectEqual(second, Recorder.receiver.?);
    try std.testing.expectEqual(@as(usize, 9), Recorder.value);
}
