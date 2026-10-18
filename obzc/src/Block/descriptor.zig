const c = @import("../c.zig").c;
const rt = @import("../rt/root.zig");

pub fn isObject(comptime T: type) bool {
    return T == *rt.Object or T == ?*rt.Object;
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
    const std = @import("std");
    const B = extern struct { header: usize, context: i32 };
    const signature: [:0]const u8 = "v@?";
    const descriptor = Descriptor(B).init(signature);
    try std.testing.expectEqual(@as(c_ulong, 0), descriptor.reserved);
    try std.testing.expectEqual(@as(c_ulong, @sizeOf(B)), descriptor.size);
    try std.testing.expectEqual(signature.ptr, descriptor.signature);
}

test "DescriptorWithHelpers.init: metadata and object ownership callbacks" {
    const std = @import("std");
    // Exercise this descriptor independently: Block does not select it yet.
    const B = extern struct { context: *rt.Object };
    const Probe = struct {
        var deallocated = false;

        fn dealloc(self: *rt.Object, sel: *rt.Sel) callconv(.c) void {
            deallocated = true;
            rt.msgSendSuper(self, rt.getClass("NSObject").?, void, sel, .{});
        }
    };
    Probe.deallocated = false;
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ZigBlockDescriptorOwnershipTest", 0).?;
    defer rt.disposeClassPair(class);
    try std.testing.expect(class.addMethod(rt.Sel.registerName("dealloc"), &Probe.dealloc, "v@:"));
    rt.registerClassPair(class);
    const object = rt.msgSend(class, ?*rt.Object, rt.Sel.registerName("new"), .{}).?;
    var source_owns = true;
    defer if (source_owns) rt.release(object);

    const signature: [:0]const u8 = "v@?";
    const descriptor = DescriptorWithHelpers(B).init(signature);
    try std.testing.expectEqual(@as(c_ulong, 0), descriptor.reserved);
    try std.testing.expectEqual(@as(c_ulong, @sizeOf(B)), descriptor.size);
    try std.testing.expectEqual(signature.ptr, descriptor.signature);

    const source: B = .{ .context = object };
    var destination: B = undefined;
    descriptor.copy_helper(&destination, &source);
    defer if (!Probe.deallocated) descriptor.dispose_helper(&destination);
    try std.testing.expectEqual(source.context, destination.context);

    rt.release(object);
    source_owns = false;
    try std.testing.expect(!Probe.deallocated);
    descriptor.dispose_helper(&destination);
    try std.testing.expect(Probe.deallocated);
}
