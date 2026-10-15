const std = @import("std");
const builtin = @import("builtin");
const c = @import("../c.zig").c;
const Class = @import("Class.zig").Class;
const Object = @import("Object.zig").Object;
const Protocol = @import("Protocol.zig").Protocol;
const Sel = @import("Sel.zig").Sel;

// Match objc_super's C layout while allowing a tagged receiver, whose bits need not
// satisfy the alignment of the struct_objc_object imported from objc/objc.h.
const Super = extern struct {
    receiver: *Object,
    super_class: *Class,
};

comptime {
    if (@sizeOf(Super) != @sizeOf(c.struct_objc_super) or
        @alignOf(Super) != @alignOf(c.struct_objc_super) or
        @offsetOf(Super, "receiver") != @offsetOf(c.struct_objc_super, "receiver") or
        @offsetOf(Super, "super_class") != @offsetOf(c.struct_objc_super, "super_class"))
    {
        @compileError("Super must match objc_super's C layout");
    }
}

/// Sends `sel` to `target` by calling objc_msgSend cast to `fn (@TypeOf(target), SEL, args...) Return`.
/// `Return` and the types of `args` must match the method's declaration exactly; mismatches are not caught at compile time.
pub fn msgSend(target: anytype, comptime Return: type, sel: *Sel, args: anytype) Return {
    // See objc/message.h: x86_64 needs objc_msgSend_stret for structs returned in memory
    // and objc_msgSend_fpret for long double; arm64 uses objc_msgSend for everything.
    const send = comptime switch (builtin.target.cpu.arch) {
        .aarch64 => &c.objc_msgSend,
        .x86_64 => if (@typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16)
            &c.objc_msgSend_stret
        else if (Return == c_longdouble)
            &c.objc_msgSend_fpret
        else
            &c.objc_msgSend,
        else => @compileError("unsupported architecture for objc_msgSend"),
    };
    const f: *const MsgSendFn(@TypeOf(target), Return, @TypeOf(args)) = @ptrCast(send);
    return @call(.auto, f, .{ target, @as(c.SEL, @ptrCast(sel)) } ++ args);
}

/// Like `msgSend`, but starts the method lookup at `superclass` instead of `target`'s class.
pub fn msgSendSuper(target: anytype, superclass: *Class, comptime Return: type, sel: *Sel, args: anytype) Return {
    // There is no objc_msgSendSuper_fpret: the receiver of a super send is never nil.
    const send = comptime switch (builtin.target.cpu.arch) {
        .aarch64 => &c.objc_msgSendSuper,
        .x86_64 => if (@typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16)
            &c.objc_msgSendSuper_stret
        else
            &c.objc_msgSendSuper,
        else => @compileError("unsupported architecture for objc_msgSendSuper"),
    };
    var super: Super = .{ .receiver = @ptrCast(target), .super_class = superclass };
    const f: *const MsgSendFn(*Super, Return, @TypeOf(args)) = @ptrCast(send);
    return @call(.auto, f, .{ &super, @as(c.SEL, @ptrCast(sel)) } ++ args);
}

fn MsgSendFn(comptime Target: type, comptime Return: type, comptime Args: type) type {
    const field_types = @typeInfo(Args).@"struct".field_types;
    var param_types: [field_types.len + 2]type = undefined;
    param_types[0] = Target;
    param_types[1] = c.SEL;
    for (field_types, 0..) |T, i| param_types[i + 2] = T;
    return @Fn(&param_types, &@splat(.{}), Return, .{ .@"callconv" = .c });
}

pub fn getClass(name: [:0]const u8) ?*Class {
    return @ptrCast(c.objc_getClass(name));
}

/// Unlike `getClass`, logs a message to stderr when no class named `name` exists.
pub fn getMetaClass(name: [:0]const u8) ?*Class {
    return @ptrCast(c.objc_getMetaClass(name));
}

/// Returns null if a class named `name` already exists.
pub fn allocateClassPair(superclass: ?*Class, name: [:0]const u8, extra_bytes: usize) ?*Class {
    return @ptrCast(c.objc_allocateClassPair(@ptrCast(superclass), name, extra_bytes));
}

pub fn registerClassPair(cls: *Class) void {
    c.objc_registerClassPair(@ptrCast(cls));
}

/// Must not be called while instances of `cls` or its subclasses exist.
pub fn disposeClassPair(cls: *Class) void {
    c.objc_disposeClassPair(@ptrCast(cls));
}

pub fn getProtocol(name: [:0]const u8) ?*Protocol {
    return @ptrCast(c.objc_getProtocol(name));
}

pub const AssociationPolicy = enum(usize) {
    assign = c.OBJC_ASSOCIATION_ASSIGN,
    retain_nonatomic = c.OBJC_ASSOCIATION_RETAIN_NONATOMIC,
    copy_nonatomic = c.OBJC_ASSOCIATION_COPY_NONATOMIC,
    retain = c.OBJC_ASSOCIATION_RETAIN,
    copy = c.OBJC_ASSOCIATION_COPY,
};

/// `key` is compared by address, so it is usually the address of a global variable. A null `value` removes the association.
pub fn setAssociatedObject(object: *Object, key: *const anyopaque, value: ?*Object, policy: AssociationPolicy) void {
    const f: *const fn (*Object, *const anyopaque, ?*Object, usize) callconv(.c) void = @ptrCast(&c.objc_setAssociatedObject);
    f(object, key, value, @intFromEnum(policy));
}

pub fn getAssociatedObject(object: *Object, key: *const anyopaque) ?*Object {
    const f: *const fn (*Object, *const anyopaque) callconv(.c) ?*Object = @ptrCast(&c.objc_getAssociatedObject);
    return f(object, key);
}

/// Called when a collection is mutated during fast enumeration. Runs the handler installed with
/// `setEnumerationMutationHandler`; the default one throws an exception.
pub fn enumerationMutation(obj: *Object) void {
    const f: *const fn (*Object) callconv(.c) void = @ptrCast(&c.objc_enumerationMutation);
    f(obj);
}

/// The handler is process-wide, and the previous one cannot be retrieved.
pub fn setEnumerationMutationHandler(handler: ?*const fn (*Object) callconv(.c) void) void {
    c.objc_setEnumerationMutationHandler(@ptrCast(handler));
}

pub fn retain(obj: *Object) *Object {
    // Tagged pointers need the runtime call without an alignment cast to imported `id`.
    const f: *const fn (*Object) callconv(.c) *Object = @ptrCast(&c.objc_retain);
    return f(obj);
}

pub fn release(obj: *Object) void {
    const f: *const fn (*Object) callconv(.c) void = @ptrCast(&c.objc_release);
    f(obj);
}

pub fn autoreleasePoolPush() *anyopaque {
    return c.objc_autoreleasePoolPush().?;
}

pub fn autoreleasePoolPop(pool: *anyopaque) void {
    c.objc_autoreleasePoolPop(pool);
}

test "msgSend / msgSendSuper: class and instance targets, arguments, integer and large struct returns" {
    const objc = @import("root.zig");
    const Big = extern struct { x: u64, y: u64, z: u64 };
    const impl = struct {
        fn hash(_: *objc.Object, _: c.SEL) callconv(.c) usize {
            return 42;
        }
        fn big(_: *objc.Object, _: c.SEL, x: u64) callconv(.c) Big {
            return .{ .x = x, .y = x + 1, .z = x + 2 };
        }
    };
    const NSObject = getClass("NSObject").?;
    const Sub = allocateClassPair(NSObject, "NativeObjcMsgSendTest", 0).?;
    try std.testing.expect(Sub.addMethod(objc.Sel.registerName("hash"), &impl.hash, "Q@:"));
    try std.testing.expect(Sub.addMethod(objc.Sel.registerName("big:"), &impl.big, "{Big=QQQ}@:Q"));
    registerClassPair(Sub);
    defer disposeClassPair(Sub);

    const obj = msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);

    try std.testing.expectEqual(42, msgSend(obj, usize, Sel.registerName("hash"), .{}));
    // NSObject's -hash returns the object's address.
    try std.testing.expectEqual(@intFromPtr(obj), msgSendSuper(obj, NSObject, usize, Sel.registerName("hash"), .{}));
    try std.testing.expectEqual(Big{ .x = 7, .y = 8, .z = 9 }, msgSend(obj, Big, Sel.registerName("big:"), .{@as(u64, 7)}));
}

test "getClass / getMetaClass / retain / release / autoreleasePool" {
    try std.testing.expectEqual(null, getClass("NoSuchClassInThisProcess"));
    const meta = getMetaClass("NSString").?;
    try std.testing.expect(meta.isMetaClass());
    try std.testing.expectEqualStrings("NSString", meta.getName());

    const obj = msgSend(getClass("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);

    try std.testing.expectEqual(obj, retain(obj));
    try std.testing.expectEqual(2, msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
    release(obj);

    const pool = autoreleasePoolPush();
    _ = msgSend(retain(obj), ?*Object, Sel.registerName("autorelease"), .{});
    try std.testing.expectEqual(2, msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
    autoreleasePoolPop(pool);
    try std.testing.expectEqual(1, msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
}

test "tagged NSNumber: msgSendSuper, retain / release, and associated objects" {
    const NSNumber = getClass("NSNumber").?;
    const allocated = msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer release(number);
    try std.testing.expect(@intFromPtr(number) % @alignOf(c.struct_objc_object) != 0);

    try std.testing.expectEqual(number, retain(number));
    release(number);
    try std.testing.expectEqual(42, msgSend(number, isize, Sel.registerName("integerValue"), .{}));
    try std.testing.expectEqual(number.getClass(), msgSendSuper(number, getClass("NSObject").?, *Class, Sel.registerName("class"), .{}));

    const obj = msgSend(getClass("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);
    const keys = struct {
        var receiver: u8 = 0;
        var value: u8 = 0;
    };

    setAssociatedObject(number, &keys.receiver, obj, .retain_nonatomic);
    defer setAssociatedObject(number, &keys.receiver, null, .retain_nonatomic);
    try std.testing.expectEqual(obj, getAssociatedObject(number, &keys.receiver).?);

    setAssociatedObject(obj, &keys.value, number, .retain_nonatomic);
    defer setAssociatedObject(obj, &keys.value, null, .retain_nonatomic);
    try std.testing.expectEqual(number, getAssociatedObject(obj, &keys.value).?);
}

test "setAssociatedObject / getAssociatedObject" {
    const key = struct {
        var value: u8 = 0;
    };
    const NSObject = getClass("NSObject").?;
    const obj = msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);
    const value = msgSend(NSObject, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(value);

    try std.testing.expectEqual(null, getAssociatedObject(obj, &key.value));
    setAssociatedObject(obj, &key.value, value, .retain);
    try std.testing.expectEqual(2, msgSend(value, usize, Sel.registerName("retainCount"), .{}));
    {
        // With an atomic policy the getter returns the value retained and autoreleased.
        const pool = autoreleasePoolPush();
        defer autoreleasePoolPop(pool);
        try std.testing.expectEqual(value, getAssociatedObject(obj, &key.value).?);
    }
    try std.testing.expectEqual(2, msgSend(value, usize, Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, null, .retain);
    try std.testing.expectEqual(null, getAssociatedObject(obj, &key.value));
    try std.testing.expectEqual(1, msgSend(value, usize, Sel.registerName("retainCount"), .{}));

    setAssociatedObject(obj, &key.value, value, .assign);
    try std.testing.expectEqual(1, msgSend(value, usize, Sel.registerName("retainCount"), .{}));
    setAssociatedObject(obj, &key.value, null, .assign);
}

test "enumerationMutation / setEnumerationMutationHandler" {
    const handler = struct {
        var mutated: ?*Object = null;
        fn f(obj: *Object) callconv(.c) void {
            mutated = obj;
        }
    };
    const obj = msgSend(getClass("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer release(obj);

    setEnumerationMutationHandler(&handler.f);
    defer setEnumerationMutationHandler(null);
    enumerationMutation(obj);
    try std.testing.expectEqual(obj, handler.mutated.?);

    const NSNumber = getClass("NSNumber").?;
    const allocated = msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer release(number);
    try std.testing.expect(@intFromPtr(number) % @alignOf(c.struct_objc_object) != 0);
    enumerationMutation(number);
    try std.testing.expectEqual(number, handler.mutated.?);
}

test "allocateClassPair / registerClassPair / disposeClassPair" {
    const NSObject = getClass("NSObject").?;
    try std.testing.expectEqual(null, allocateClassPair(NSObject, "NSObject", 0));

    const Sub = allocateClassPair(NSObject, "NativeObjcRootTest", 0).?;
    try std.testing.expectEqual(null, getClass("NativeObjcRootTest"));
    registerClassPair(Sub);
    try std.testing.expectEqual(Sub, getClass("NativeObjcRootTest").?);
    try std.testing.expectEqual(NSObject, Sub.getSuperclass().?);
    disposeClassPair(Sub);
    try std.testing.expectEqual(null, getClass("NativeObjcRootTest"));
}
