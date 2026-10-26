const std = @import("std");
const ffi = @import("../ffi/root.zig");
const c = ffi.c;
const Object = ffi.Object;

pub fn isObject(comptime T: type) bool {
    return T == *Object or T == ?*Object;
}

/// Descriptor for a block with a signature and no copy/dispose helpers.
pub fn Descriptor(comptime Block: type) type {
    return extern struct {
        reserved: c_ulong,
        size: c_ulong,
        signature: [*:0]const u8,
        pub fn init(signature: [*:0]const u8) @This() {
            return .{
                .reserved = 0,
                .size = @sizeOf(Block),
                .signature = signature,
            };
        }
    };
}

/// Descriptor with ownership callbacks for a context that is itself an Objective-C object pointer.
/// Currently not selected by `Block`; this does not traverse fields of aggregate contexts.
pub fn DescriptorWithHelpers(comptime Block: type) type {
    return extern struct {
        const Self = @This();
        reserved: c_ulong,
        size: c_ulong,
        copy_helper: *const fn (dst: *Block, src: *const Block) callconv(.c) void,
        dispose_helper: *const fn (src: *const Block) callconv(.c) void,
        signature: [*:0]const u8,

        pub fn init(signature: [*:0]const u8) Self {
            return .{
                .reserved = 0,
                .size = @sizeOf(Block),
                .copy_helper = &copyHelper,
                .dispose_helper = &disposeHelper,
                .signature = signature,
            };
        }

        /// Called by `_Block_copy` on the new heap block after copying `src` into it bytewise.
        fn copyHelper(dst: *Block, src: *const Block) callconv(.c) void {
            c._Block_object_assign(@ptrCast(&dst.context), src.context, c.BLOCK_FIELD_IS_OBJECT);
        }

        /// Called by the last `_Block_release` of a heap block before freeing it.
        fn disposeHelper(src: *const Block) callconv(.c) void {
            c._Block_object_dispose(src.context, c.BLOCK_FIELD_IS_OBJECT);
        }
    };
}

test "Descriptor.init: reserved, block size and signature" {
    const B = extern struct { header: usize, context: i32 };
    const signature: [:0]const u8 = "v@?";
    const descriptor = Descriptor(B).init(signature);
    try std.testing.expectEqual(@as(c_ulong, 0), descriptor.reserved);
    try std.testing.expectEqual(@as(c_ulong, @sizeOf(B)), descriptor.size);
    try std.testing.expectEqual(signature.ptr, descriptor.signature);
}

test "isObject: direct runtime object pointers" {
    try std.testing.expect(isObject(*Object));
    try std.testing.expect(isObject(?*Object));
    try std.testing.expect(!isObject(*ffi.Class));
    try std.testing.expect(!isObject(extern struct { object: *Object }));
}

test "DescriptorWithHelpers.init: reserved, block size and signature" {
    const B = extern struct { context: *Object };
    const signature: [:0]const u8 = "v@?";
    const descriptor = DescriptorWithHelpers(B).init(signature);
    try std.testing.expectEqual(@as(c_ulong, 0), descriptor.reserved);
    try std.testing.expectEqual(@as(c_ulong, @sizeOf(B)), descriptor.size);
    try std.testing.expectEqual(signature.ptr, descriptor.signature);
}

test "DescriptorWithHelpers: copy retains the captured object until dispose" {
    // Exercise this descriptor independently: Block does not select it yet.
    const B = extern struct { context: *Object };
    const Probe = struct {
        var deallocated = false;

        fn dealloc(self: c.id, sel: c.SEL) callconv(.c) void {
            deallocated = true;
            var super: c.struct_objc_super = .{
                .receiver = self,
                .super_class = c.objc_getClass("NSObject"),
            };
            const send: *const fn (*c.struct_objc_super, c.SEL) callconv(.c) void = @ptrCast(&c.objc_msgSendSuper);
            send(&super, sel);
        }
    };
    const class = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcBlockDescriptorOwnershipTest", 0).?;
    defer c.objc_disposeClassPair(class);
    try std.testing.expect(c.class_addMethod(class, c.sel_registerName("dealloc"), @ptrCast(&Probe.dealloc), "v@:") == c.YES);
    c.objc_registerClassPair(class);
    const descriptor = DescriptorWithHelpers(B).init("v@?");
    var destination: B = undefined;
    {
        const send: *const fn (c.Class, c.SEL) callconv(.c) c.id = @ptrCast(&c.objc_msgSend);
        const object: *Object = @ptrCast(send(class, c.sel_registerName("new")).?);
        defer c.objc_release(@ptrCast(object));
        const source: B = .{ .context = object };
        descriptor.copy_helper(&destination, &source);
        errdefer descriptor.dispose_helper(&destination);
        try std.testing.expectEqual(source.context, destination.context);
    }
    {
        defer if (!Probe.deallocated) descriptor.dispose_helper(&destination);
        try std.testing.expect(!Probe.deallocated);
    }
    try std.testing.expect(Probe.deallocated);
}

test "DescriptorWithHelpers: null object captures need no ownership" {
    const B = extern struct { context: ?*Object };
    const descriptor = DescriptorWithHelpers(B).init("v@?");
    const source: B = .{ .context = null };
    var destination: B = undefined;
    descriptor.copy_helper(&destination, &source);
    try std.testing.expectEqual(null, destination.context);
    descriptor.dispose_helper(&destination);
}
