const std = @import("std");
const objc = @import("root.zig");
const builtin = @import("builtin");
const c = @import("../../../ffi/root.zig").c;
const Class = @import("../Class.zig").Class;
const Object = @import("../Object.zig").Object;
const Sel = @import("../Sel.zig").Sel;

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
    return @call(.auto, f, .{ target, sel } ++ args);
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
    var super: c.struct_objc_super = .{ .receiver = @ptrCast(target), .super_class = @ptrCast(superclass) };
    const f: *const MsgSendFn(*c.struct_objc_super, Return, @TypeOf(args)) = @ptrCast(send);
    return @call(.auto, f, .{ &super, sel } ++ args);
}

fn MsgSendFn(comptime Target: type, comptime Return: type, comptime Args: type) type {
    const field_types = @typeInfo(Args).@"struct".field_types;
    var param_types: [field_types.len + 2]type = undefined;
    param_types[0] = Target;
    param_types[1] = *Sel;
    for (field_types, 0..) |T, i| param_types[i + 2] = T;
    return @Fn(&param_types, &@splat(.{}), Return, .{ .@"callconv" = .c });
}

test "msgSend / msgSendSuper: dispatch starts at the receiver or superclass" {
    const impl = struct {
        fn parent(_: *Object, _: *Sel) callconv(.c) usize {
            return 11;
        }
        fn child(_: *Object, _: *Sel) callconv(.c) usize {
            return 42;
        }
    };
    const sel = Sel.registerName("answer");
    const NSObject = objc.getClass("NSObject").?;
    const Parent = objc.allocateClassPair(NSObject, "NativeObjcMsgSendParentTest", 0).?;
    defer objc.disposeClassPair(Parent);
    try std.testing.expect(Parent.addMethod(sel, &impl.parent, "Q@:"));
    objc.registerClassPair(Parent);
    const Sub = objc.allocateClassPair(Parent, "NativeObjcMsgSendTest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addMethod(sel, &impl.child, "Q@:"));
    objc.registerClassPair(Sub);
    const obj = msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);

    try std.testing.expectEqual(42, msgSend(obj, usize, sel, .{}));
    try std.testing.expectEqual(11, msgSendSuper(obj, Parent, usize, sel, .{}));
}

test "msgSend / msgSendSuper: floating-point and aggregate ABI" {
    const Point = extern struct { x: f64, y: f64 };
    const Big = extern struct { x: u64, y: u64, z: u64 };
    const impl = struct {
        fn big(_: *Object, _: *Sel, x: u64) callconv(.c) Big {
            return .{ .x = x, .y = x + 1, .z = x + 2 };
        }
        fn subBig(_: *Object, _: *Sel, x: u64) callconv(.c) Big {
            return .{ .x = x + 10, .y = x + 11, .z = x + 12 };
        }
        fn transform(_: *Object, _: *Sel, point: Point, scale: f64, offset: i32) callconv(.c) Point {
            return .{ .x = point.x * scale + @as(f64, @floatFromInt(offset)), .y = point.y * scale };
        }
        fn extended(_: *Object, _: *Sel, value: c_longdouble) callconv(.c) c_longdouble {
            return value + 0.5;
        }
    };
    const big = Sel.registerName("big:");
    const transform = Sel.registerName("transform:scale:offset:");
    const extended = Sel.registerName("extended:");
    const NSObject = objc.getClass("NSObject").?;
    const Parent = objc.allocateClassPair(NSObject, "NativeObjcMsgSendABIParentTest", 0).?;
    defer objc.disposeClassPair(Parent);
    try std.testing.expect(Parent.addMethod(big, &impl.big, "{Big=QQQ}@:Q"));
    try std.testing.expect(Parent.addMethod(transform, &impl.transform, "{Point=dd}@:{Point=dd}di"));
    try std.testing.expect(Parent.addMethod(extended, &impl.extended, "D@:D"));
    objc.registerClassPair(Parent);
    const Sub = objc.allocateClassPair(Parent, "NativeObjcMsgSendABITest", 0).?;
    defer objc.disposeClassPair(Sub);
    try std.testing.expect(Sub.addMethod(big, &impl.subBig, "{Big=QQQ}@:Q"));
    objc.registerClassPair(Sub);
    const obj = msgSend(Sub, ?*Object, Sel.registerName("new"), .{}).?;
    defer objc.release(obj);

    try std.testing.expectEqual(Big{ .x = 17, .y = 18, .z = 19 }, msgSend(obj, Big, big, .{@as(u64, 7)}));
    try std.testing.expectEqual(Big{ .x = 7, .y = 8, .z = 9 }, msgSendSuper(obj, Parent, Big, big, .{@as(u64, 7)}));

    const args = .{ Point{ .x = 2, .y = 3 }, @as(f64, 1.5), @as(i32, -2) };
    const expected: Point = .{ .x = 1, .y = 4.5 };
    try std.testing.expectEqual(expected, msgSend(obj, Point, transform, args));
    try std.testing.expectEqual(expected, msgSendSuper(obj, Parent, Point, transform, args));
    try std.testing.expectEqual(@as(c_longdouble, 6.75), msgSend(obj, c_longdouble, extended, .{@as(c_longdouble, 6.25)}));
    try std.testing.expectEqual(@as(c_longdouble, 6.75), msgSendSuper(obj, Parent, c_longdouble, extended, .{@as(c_longdouble, 6.25)}));
}

test "msgSend / msgSendSuper: NSNumber receiver" {
    const NSNumber = objc.getClass("NSNumber").?;
    const allocated = msgSend(NSNumber, ?*Object, Sel.registerName("alloc"), .{}).?;
    const number = msgSend(allocated, ?*Object, Sel.registerName("initWithInteger:"), .{@as(isize, 42)}).?;
    defer objc.release(number);

    try std.testing.expectEqual(42, msgSend(number, isize, Sel.registerName("integerValue"), .{}));
    try std.testing.expectEqual(number.getClass(), msgSendSuper(number, objc.getClass("NSObject").?, *Class, Sel.registerName("class"), .{}));
}

test "msgSend: class receiver" {
    const NSObject = objc.getClass("NSObject").?;
    try std.testing.expectEqual(NSObject, msgSend(NSObject, *Class, Sel.registerName("class"), .{}));
    try std.testing.expectEqual(null, msgSend(NSObject, ?*Class, Sel.registerName("superclass"), .{}));
}

test "msgSend: nil receiver returns zero scalars and null objects" {
    const receiver: ?*Object = null;
    try std.testing.expectEqual(@as(usize, 0), msgSend(receiver, usize, Sel.registerName("hash"), .{}));
    try std.testing.expectEqual(@as(f64, 0), msgSend(receiver, f64, Sel.registerName("doubleValue"), .{}));
    try std.testing.expectEqual(null, msgSend(receiver, ?*Object, Sel.registerName("self"), .{}));
}
