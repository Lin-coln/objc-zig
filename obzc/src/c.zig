const std = @import("std");

pub const c = @import("objc-abi");

test "runtime.h + message.h: define subclass at runtime, msgSend / msgSendSuper" {
    const NSObject = c.objc_getClass("NSObject");
    const Sub = c.objc_allocateClassPair(NSObject, "NativeObjcTestSub", 0) orelse return error.ClassAllocFailed;
    const hash = struct {
        fn f(_: c.id, _: c.SEL) callconv(.c) usize {
            return 42;
        }
    }.f;
    try std.testing.expect(c.class_addMethod(Sub, c.sel_registerName("hash"), @ptrCast(&hash), "Q@:") == c.YES);
    c.objc_registerClassPair(Sub);
    defer c.objc_disposeClassPair(Sub);

    const new: *const fn (c.Class, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
    const obj = new(Sub, c.sel_registerName("new"));
    defer c.objc_release(obj);

    const send: *const fn (c.id, c.SEL) callconv(.c) usize = @ptrCast(&c.objc_msgSend);
    try std.testing.expectEqual(42, send(obj, c.sel_registerName("hash")));

    // NSObject's -hash returns the object's address.
    const sendSuper: *const fn (*c.struct_objc_super, c.SEL) callconv(.c) usize = @ptrCast(&c.objc_msgSendSuper);
    var super: c.struct_objc_super = .{ .receiver = obj, .super_class = NSObject };
    try std.testing.expectEqual(@intFromPtr(obj), sendSuper(&super, c.sel_registerName("hash")));
}

test "objc_retain / objc_release / autoreleasePool" {
    const new: *const fn (c.Class, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
    const send: *const fn (c.id, c.SEL) callconv(.c) usize = @ptrCast(&c.objc_msgSend);
    const obj = new(c.objc_getClass("NSObject"), c.sel_registerName("new"));
    defer c.objc_release(obj);

    try std.testing.expectEqual(1, send(obj, c.sel_registerName("retainCount")));
    _ = c.objc_retain(obj);
    try std.testing.expectEqual(2, send(obj, c.sel_registerName("retainCount")));
    c.objc_release(obj);
    try std.testing.expectEqual(1, send(obj, c.sel_registerName("retainCount")));

    const pool = c.objc_autoreleasePoolPush();
    _ = c.objc_retain(obj);
    _ = send(obj, c.sel_registerName("autorelease"));
    try std.testing.expectEqual(2, send(obj, c.sel_registerName("retainCount")));
    c.objc_autoreleasePoolPop(pool);
    try std.testing.expectEqual(1, send(obj, c.sel_registerName("retainCount")));
}

test "Block.h: copy stack block to heap with _Block_copy and invoke it" {
    // Block literal layout from the Apple Block ABI; Block.h declares only the functions, not this struct.
    const Descriptor = extern struct { reserved: c_ulong, size: c_ulong };
    const Block = extern struct {
        isa: ?*anyopaque,
        flags: c_int,
        reserved: c_int,
        invoke: *const fn (*const @This()) callconv(.c) c_int,
        descriptor: *const Descriptor,
        captured: c_int,
    };
    const invoke = struct {
        fn f(block: *const Block) callconv(.c) c_int {
            return block.captured * 2;
        }
    }.f;

    const block: Block = .{
        .isa = &c._NSConcreteStackBlock,
        .flags = 0,
        .reserved = 0,
        .invoke = &invoke,
        .descriptor = &.{ .reserved = 0, .size = @sizeOf(Block) },
        .captured = 21,
    };
    const copied: *const Block = @ptrCast(@alignCast(c._Block_copy(&block) orelse return error.BlockCopyFailed));
    defer c._Block_release(copied);

    try std.testing.expect(copied != &block);
    try std.testing.expectEqual(42, copied.invoke(copied));
}

test "Block.h: _Block_object_assign / _Block_object_dispose retain and release a captured object" {
    // Constants and descriptor layout from the Apple Block ABI; Block.h does not declare them.
    const BLOCK_HAS_COPY_DISPOSE = 1 << 25;
    const BLOCK_FIELD_IS_OBJECT = 3;
    const Block = extern struct {
        isa: ?*anyopaque,
        flags: c_int,
        reserved: c_int,
        invoke: *const fn (*const @This()) callconv(.c) void,
        descriptor: *const Descriptor,
        captured: c.id,

        const Self = @This();
        const Descriptor = extern struct {
            reserved: c_ulong,
            size: c_ulong,
            copy_helper: *const fn (dst: *Self, src: *const Self) callconv(.c) void,
            dispose_helper: *const fn (src: *const Self) callconv(.c) void,
        };
    };
    // What clang generates for a block that captures an object: _Block_copy calls copy_helper on the
    // new heap block, and the last _Block_release calls dispose_helper before freeing it.
    const helpers = struct {
        fn invoke(_: *const Block) callconv(.c) void {}
        fn copy(dst: *Block, src: *const Block) callconv(.c) void {
            c._Block_object_assign(@ptrCast(&dst.captured), src.captured, BLOCK_FIELD_IS_OBJECT);
        }
        fn dispose(src: *const Block) callconv(.c) void {
            c._Block_object_dispose(src.captured, BLOCK_FIELD_IS_OBJECT);
        }
    };

    const new: *const fn (c.Class, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
    const send: *const fn (c.id, c.SEL) callconv(.c) usize = @ptrCast(&c.objc_msgSend);
    const obj = new(c.objc_getClass("NSObject"), c.sel_registerName("new"));
    defer c.objc_release(obj);

    const block: Block = .{
        .isa = &c._NSConcreteStackBlock,
        .flags = BLOCK_HAS_COPY_DISPOSE,
        .reserved = 0,
        .invoke = &helpers.invoke,
        .descriptor = &.{ .reserved = 0, .size = @sizeOf(Block), .copy_helper = &helpers.copy, .dispose_helper = &helpers.dispose },
        .captured = obj,
    };
    // A stack block does not own what it captures.
    try std.testing.expectEqual(1, send(obj, c.sel_registerName("retainCount")));

    const copied: *const Block = @ptrCast(@alignCast(c._Block_copy(&block) orelse return error.BlockCopyFailed));
    try std.testing.expectEqual(obj, copied.captured);
    try std.testing.expectEqual(2, send(obj, c.sel_registerName("retainCount")));

    c._Block_release(copied);
    try std.testing.expectEqual(1, send(obj, c.sel_registerName("retainCount")));
}
