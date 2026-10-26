const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig").c;
const Class = @import("Class.zig").Class;
const Object = @import("Object.zig").Object;
const Sel = @import("Sel.zig").Sel;

/// Sends `sel` to `target` by calling objc_msgSend cast to `fn (@TypeOf(target), SEL, args...) Return`.
/// `Return` and the types of `args` must match the method's declaration exactly; mismatches are not caught at compile time.
pub fn send(target: anytype, comptime Return: type, sel: *Sel, args: anytype) Return {
    // See objc/message.h: x86_64 needs objc_msgSend_stret for structs returned in memory
    // and objc_msgSend_fpret for long double; arm64 uses objc_msgSend for everything.
    const entry = comptime switch (builtin.target.cpu.arch) {
        .aarch64 => &c.objc_msgSend,
        .x86_64 => if (@typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16)
            &c.objc_msgSend_stret
        else if (Return == c_longdouble)
            &c.objc_msgSend_fpret
        else
            &c.objc_msgSend,
        else => @compileError("unsupported architecture for objc_msgSend"),
    };
    const f: *const MsgSendFn(@TypeOf(target), Return, @TypeOf(args)) = @ptrCast(entry);
    return @call(.auto, f, .{ target, sel } ++ args);
}

/// Like `send`, but starts the method lookup at `superclass` instead of `target`'s class.
pub fn sendSuper(target: anytype, superclass: *Class, comptime Return: type, sel: *Sel, args: anytype) Return {
    // There is no objc_msgSendSuper_fpret: the receiver of a super send is never nil.
    const entry = comptime switch (builtin.target.cpu.arch) {
        .aarch64 => &c.objc_msgSendSuper,
        .x86_64 => if (@typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16)
            &c.objc_msgSendSuper_stret
        else
            &c.objc_msgSendSuper,
        else => @compileError("unsupported architecture for objc_msgSendSuper"),
    };
    var super: c.struct_objc_super = .{ .receiver = @ptrCast(target), .super_class = @ptrCast(superclass) };
    const f: *const MsgSendFn(*c.struct_objc_super, Return, @TypeOf(args)) = @ptrCast(entry);
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

test "ffi msg: send builds C signatures for class and instance receivers" {
    const pool = c.objc_autoreleasePoolPush();
    defer c.objc_autoreleasePoolPop(pool);
    const number_class = Class.lookup("NSNumber").?;
    const number = send(number_class, ?*Object, Sel.get("numberWithInteger:"), .{@as(isize, -42)}).?;
    try std.testing.expectEqual(-42, send(number, isize, Sel.get("integerValue"), .{}));
    try std.testing.expectEqual(@as(*Class, @ptrCast(c.object_getClass(@ptrCast(number)).?)), send(number, *Class, Sel.get("class"), .{}));
    const immutable: *const Object = number;
    try std.testing.expectEqual(-42, send(immutable, isize, Sel.get("integerValue"), .{}));
}

test "ffi msg: normal and super calls preserve receiver and aggregate ABI" {
    const Point = extern struct { x: f64, y: f64 };
    const Big = extern struct { a: u64, b: u64, c: u64 };
    const Methods = struct {
        fn parent(self: *Object, _: *Sel) callconv(.c) *Object {
            return self;
        }
        fn child(_: *Object, _: *Sel) callconv(.c) ?*Object {
            return null;
        }
        fn big(_: *Object, _: *Sel, value: u64) callconv(.c) Big {
            return .{ .a = value, .b = value + 1, .c = value + 2 };
        }
        fn transform(_: *Object, _: *Sel, point: Point, scale: f64, offset: i32) callconv(.c) Point {
            return .{ .x = point.x * scale + @as(f64, @floatFromInt(offset)), .y = point.y * scale };
        }
        fn extended(_: *Object, _: *Sel, value: c_longdouble) callconv(.c) c_longdouble {
            return value + 0.5;
        }
        fn classParent(_: *Class, _: *Sel) callconv(.c) usize {
            return 11;
        }
        fn classChild(_: *Class, _: *Sel) callconv(.c) usize {
            return 42;
        }
    };
    const parent_c = c.objc_allocateClassPair(@ptrCast(Class.lookup("NSObject").?), "ObzcFfiMsgParent", 0).?;
    defer c.objc_disposeClassPair(parent_c);
    try std.testing.expect(c.class_addMethod(parent_c, @ptrCast(Sel.get("identity")), @ptrCast(&Methods.parent), "@@:") == c.YES);
    try std.testing.expect(c.class_addMethod(parent_c, @ptrCast(Sel.get("big:")), @ptrCast(&Methods.big), "{Big=QQQ}@:Q") == c.YES);
    try std.testing.expect(c.class_addMethod(parent_c, @ptrCast(Sel.get("transform:scale:offset:")), @ptrCast(&Methods.transform), "{Point=dd}@:{Point=dd}di") == c.YES);
    try std.testing.expect(c.class_addMethod(parent_c, @ptrCast(Sel.get("extended:")), @ptrCast(&Methods.extended), if (c_longdouble == f64) "d@:d" else "D@:D") == c.YES);
    c.objc_registerClassPair(parent_c);
    const child_c = c.objc_allocateClassPair(parent_c, "ObzcFfiMsgChild", 0).?;
    defer c.objc_disposeClassPair(child_c);
    try std.testing.expect(c.class_addMethod(child_c, @ptrCast(Sel.get("identity")), @ptrCast(&Methods.child), "@@:") == c.YES);
    c.objc_registerClassPair(child_c);

    const parent: *Class = @ptrCast(parent_c);
    const child: *Class = @ptrCast(child_c);
    const object = send(child, ?*Object, Sel.get("new"), .{}).?;
    defer c.objc_release(@ptrCast(object));
    try std.testing.expectEqual(null, send(object, ?*Object, Sel.get("identity"), .{}));
    try std.testing.expectEqual(object, sendSuper(object, parent, *Object, Sel.get("identity"), .{}));

    const args = .{ Point{ .x = 2, .y = 3 }, @as(f64, 1.5), @as(i32, -2) };
    try std.testing.expectEqualDeep(Point{ .x = 1, .y = 4.5 }, send(object, Point, Sel.get("transform:scale:offset:"), args));
    try std.testing.expectEqualDeep(Point{ .x = 1, .y = 4.5 }, sendSuper(object, parent, Point, Sel.get("transform:scale:offset:"), args));
    try std.testing.expectEqualDeep(Big{ .a = 7, .b = 8, .c = 9 }, send(object, Big, Sel.get("big:"), .{@as(u64, 7)}));
    try std.testing.expectEqualDeep(Big{ .a = 7, .b = 8, .c = 9 }, sendSuper(object, parent, Big, Sel.get("big:"), .{@as(u64, 7)}));
    try std.testing.expectEqual(@as(c_longdouble, 6.75), send(object, c_longdouble, Sel.get("extended:"), .{@as(c_longdouble, 6.25)}));
    try std.testing.expectEqual(@as(c_longdouble, 6.75), sendSuper(object, parent, c_longdouble, Sel.get("extended:"), .{@as(c_longdouble, 6.25)}));

    const parent_meta = c.object_getClass(@ptrCast(parent)).?;
    const child_meta = c.object_getClass(@ptrCast(child)).?;
    const selector = Sel.get("classAnswer");
    try std.testing.expect(c.class_addMethod(parent_meta, @ptrCast(selector), @ptrCast(&Methods.classParent), "Q@:") == c.YES);
    try std.testing.expect(c.class_addMethod(child_meta, @ptrCast(selector), @ptrCast(&Methods.classChild), "Q@:") == c.YES);
    try std.testing.expectEqual(42, send(child, usize, selector, .{}));
    try std.testing.expectEqual(11, sendSuper(child, @ptrCast(parent_meta), usize, selector, .{}));
}
