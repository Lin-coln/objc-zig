const std = @import("std");

pub const c = @import("objc-abi");

test "runtime.h + message.h: define subclass at runtime, msgSend / msgSendSuper" {
    const NSObject = c.objc_getClass("NSObject").?;
    const Sub = c.objc_allocateClassPair(NSObject, "NativeObjcTestSub", 0) orelse return error.ClassAllocFailed;
    defer c.objc_disposeClassPair(Sub);
    const hash = struct {
        fn f(_: c.id, _: c.SEL) callconv(.c) usize {
            return 42;
        }
    }.f;
    try std.testing.expect(c.class_addMethod(Sub, c.sel_registerName("hash"), @ptrCast(&hash), "Q@:") == c.YES);
    c.objc_registerClassPair(Sub);

    const new: *const fn (c.Class, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
    const obj = new(Sub, c.sel_registerName("new")).?;
    defer c.objc_release(obj);

    const send: *const fn (c.id, c.SEL) callconv(.c) usize = @ptrCast(&c.objc_msgSend);
    try std.testing.expectEqual(42, send(obj, c.sel_registerName("hash")));

    const sendSuper: *const fn (*c.struct_objc_super, c.SEL) callconv(.c) c.Class = @ptrCast(&c.objc_msgSendSuper);
    var super: c.struct_objc_super = .{ .receiver = obj, .super_class = NSObject };
    try std.testing.expectEqual(Sub, sendSuper(&super, c.sel_registerName("class")));
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
    // The descriptor layout follows the Apple Block ABI; Block.h does not declare it.
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
            c._Block_object_assign(@ptrCast(&dst.captured), src.captured, c.BLOCK_FIELD_IS_OBJECT);
        }
        fn dispose(src: *const Block) callconv(.c) void {
            c._Block_object_dispose(src.captured, c.BLOCK_FIELD_IS_OBJECT);
        }
    };

    const Probe = struct {
        var deallocated = false;

        fn dealloc(self: c.id, sel: c.SEL) callconv(.c) void {
            deallocated = true;
            const send: *const fn (*c.struct_objc_super, c.SEL) callconv(.c) void = @ptrCast(&c.objc_msgSendSuper);
            var super: c.struct_objc_super = .{ .receiver = self, .super_class = c.objc_getClass("NSObject") };
            send(&super, sel);
        }
    };
    const NSObject = c.objc_getClass("NSObject").?;
    const Sub = c.objc_allocateClassPair(NSObject, "ObjcZigCBlockOwnershipTest", 0) orelse return error.ClassAllocFailed;
    defer c.objc_disposeClassPair(Sub);
    try std.testing.expect(c.class_addMethod(Sub, c.sel_registerName("dealloc"), @ptrCast(&Probe.dealloc), "v@:") == c.YES);
    c.objc_registerClassPair(Sub);
    const new: *const fn (c.Class, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
    const copied = blk: {
        const obj = new(Sub, c.sel_registerName("new")).?;
        defer c.objc_release(obj);
        const block: Block = .{
            .isa = &c._NSConcreteStackBlock,
            .flags = c.BLOCK_HAS_COPY_DISPOSE,
            .reserved = 0,
            .invoke = &helpers.invoke,
            .descriptor = &.{ .reserved = 0, .size = @sizeOf(Block), .copy_helper = &helpers.copy, .dispose_helper = &helpers.dispose },
            .captured = obj,
        };
        const copied: *Block = @ptrCast(@alignCast(c._Block_copy(&block) orelse return error.BlockCopyFailed));
        errdefer c._Block_release(copied);
        try std.testing.expectEqual(@as(c.id, obj), copied.captured);
        break :blk copied;
    };
    {
        defer {
            // A failed ownership check must not dispose an already-deallocated capture again.
            if (Probe.deallocated) copied.captured = null;
            c._Block_release(copied);
        }
        try std.testing.expect(!Probe.deallocated);
    }
    try std.testing.expect(Probe.deallocated);
}
