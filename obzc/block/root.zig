const std = @import("std");
const builtin = @import("builtin");
const ffi = @import("../ffi/root.zig");
const encodeFunction = @import("../encode/root.zig").encodeFunction;
const c = ffi.c;

pub fn Block(comptime Context: type, comptime Function: type) type {
    const signature = comptime encodeFunction(Function, 0, "@?");

    return extern struct {
        const Self = @This();
        // Context is currently copied bytewise, without retaining or releasing captured objects.
        // TODO: expose context copy/dispose callbacks through DescriptorWithHelpers;
        // callers must manage captured object lifetimes until these callbacks are supported.
        const Descriptor = @import("descriptor.zig").Descriptor(Self);
        const Callback = getCallbackType(Self, Function);
        isa: ?*anyopaque = &c._NSConcreteStackBlock,
        flags: c_int = getFlags(Function),
        reserved: c_int = 0,
        invoke: *const Callback,
        descriptor: *const Descriptor = &.init(signature),
        context: Context,

        /// Creates a stack block. Copy it before keeping it beyond the lifetime of its stack storage.
        pub fn init(context: Context, callback: *const Callback) Self {
            return .{
                .invoke = callback,
                .context = context,
            };
        }

        /// Copies a stack block to the heap, or retains a block that is already there. Must be balanced with `release`.
        pub fn copy(self: *const Self) ?*Self {
            return @ptrCast(@alignCast(c._Block_copy(self)));
        }

        /// Releases a heap block obtained through `copy`.
        pub fn release(self: *const Self) void {
            c._Block_release(self);
        }
    };
}

/// Sets the signature flag and, on x86_64, the stret flag for struct returns larger than 16 bytes.
/// Copy/dispose helpers are currently disabled for every context type.
fn getFlags(comptime Function: type) c_int {
    const Return = @typeInfo(Function).@"fn".return_type.?;
    // Same rule as `msgSend`: only x86_64 returns large structs through a hidden pointer argument.
    const stret = builtin.target.cpu.arch == .x86_64 and @typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16;
    return c.BLOCK_HAS_SIGNATURE |
        (if (stret) c.BLOCK_USE_STRET else 0);
}

/// Builds a C callback type with `*const BlockType` before the parameters of `Function`.
/// Preserves the explicit parameter types and return type of `Function`.
fn getCallbackType(comptime BlockType: type, comptime Function: type) type {
    const info = @typeInfo(Function).@"fn";

    var param_types: [info.param_types.len + 1]type = undefined;

    param_types[0] = *const BlockType;
    for (info.param_types, 1..) |T, i| param_types[i] = T.?;

    return @Fn(
        &param_types,
        &@splat(.{}),
        info.return_type.?,
        .{ .@"callconv" = .c },
    );
}

test "Block.init: binds the supplied context and callback" {
    const B = Block(i32, fn () void);
    const callback = struct {
        fn invoke(_: *const B) callconv(.c) void {}
    }.invoke;
    const block = B.init(7, &callback);

    try std.testing.expectEqual(7, block.context);
    try std.testing.expectEqual(&callback, block.invoke);
}

test "Block.copy: forwards the supplied block and returns its typed heap copy" {
    const B = Block(i32, fn () void);
    const callback = struct {
        fn invoke(_: *const B) callconv(.c) void {}
    }.invoke;
    const source: B = .{ .context = 42, .invoke = &callback };
    const copied = source.copy().?;
    defer c._Block_release(copied);

    try std.testing.expect(@TypeOf(copied) == *B);
    try std.testing.expect(copied != &source);
    try std.testing.expectEqual(source.context, copied.context);
    try std.testing.expectEqual(source.invoke, copied.invoke);
}

test "Block.release: releases the supplied heap block" {
    const B = Block(*bool, fn () void);
    const Fixture = struct {
        const Descriptor = extern struct {
            reserved: c_ulong = 0,
            size: c_ulong = @sizeOf(B),
            copy: *const fn (*B, *const B) callconv(.c) void = &copy,
            dispose: *const fn (*const B) callconv(.c) void = &dispose,
            signature: [*:0]const u8 = "v@?",
        };

        fn invoke(_: *const B) callconv(.c) void {}
        fn copy(_: *B, _: *const B) callconv(.c) void {}
        fn dispose(block: *const B) callconv(.c) void {
            block.context.* = true;
        }
    };
    var disposed = false;
    const descriptor: Fixture.Descriptor = .{};
    const source: B = .{
        .context = &disposed,
        .invoke = &Fixture.invoke,
        .flags = c.BLOCK_HAS_SIGNATURE | c.BLOCK_HAS_COPY_DISPOSE,
        .descriptor = @ptrCast(&descriptor),
    };
    const heap: *B = @ptrCast(@alignCast(c._Block_copy(&source).?));
    defer if (!disposed) c._Block_release(heap);

    heap.release();
    try std.testing.expect(disposed);
}

test "getFlags: signature and struct return convention" {
    const Small = extern struct { a: u64, b: u64 };
    const Big = extern struct { a: u64, b: u64, c: u64 };
    try std.testing.expectEqual(@as(c_int, c.BLOCK_HAS_SIGNATURE), comptime getFlags(fn () void));
    try std.testing.expectEqual(@as(c_int, c.BLOCK_HAS_SIGNATURE), comptime getFlags(fn () Small));
    const expected = c.BLOCK_HAS_SIGNATURE |
        (if (builtin.target.cpu.arch == .x86_64) c.BLOCK_USE_STRET else 0);
    try std.testing.expectEqual(@as(c_int, expected), comptime getFlags(fn () Big));
}

test "getCallbackType: implicit block parameter and C calling convention" {
    const B = opaque {};
    const Result = extern struct { value: i32 };
    try std.testing.expect(getCallbackType(B, fn () void) == fn (*const B) callconv(.c) void);
    try std.testing.expect(getCallbackType(B, fn (i32, ?*const u8) Result) ==
        fn (*const B, i32, ?*const u8) callconv(.c) Result);
}
