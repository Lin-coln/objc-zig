const std = @import("std");
const builtin = @import("builtin");
const ffi = @import("../ffi/root.zig");
const encode = @import("encode.zig").encode;
const c = ffi.c;

pub fn Block(comptime Context: type, comptime Function: type) type {
    const signature = comptime generateFromFnType(Function);

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

/// Encodes the return type, the implicit block argument, then the function parameters.
/// Sizes and offsets are omitted, matching the type-only signatures used by Block.
pub fn generateFromFnType(comptime Fn: type) [:0]const u8 {
    const fn_info = switch (@typeInfo(Fn)) {
        .@"fn" => |info| info,
        else => @compileError("expected a function type, got " ++ @typeName(Fn)),
    };
    if (fn_info.is_generic or fn_info.attrs.varargs) {
        @compileError("a block signature requires a non-generic function with fixed parameters");
    }
    var signature: []const u8 = encode(fn_info.return_type.?) ++ "@?";
    for (fn_info.param_types) |T| signature = signature ++ encode(T.?);
    return std.fmt.comptimePrint("{s}", .{signature});
}

test "Block.init: header, descriptor and invocation" {
    const Add = Block(i32, fn (i32) i32);
    const callback = struct {
        fn invoke(block: *const Add, value: i32) callconv(.c) i32 {
            return block.context + value;
        }
    }.invoke;
    const block = Add.init(7, &callback);

    try std.testing.expectEqual(@as(?*anyopaque, &c._NSConcreteStackBlock), block.isa);
    try std.testing.expectEqual(@as(c_int, c.BLOCK_HAS_SIGNATURE), block.flags);
    try std.testing.expectEqual(@as(c_int, 0), block.reserved);
    // Check that Block connects its full type and generated signature to the descriptor.
    try std.testing.expectEqual(@as(c_ulong, @sizeOf(Add)), block.descriptor.size);
    try std.testing.expectEqualStrings("i@?i", std.mem.span(block.descriptor.signature));
    try std.testing.expectEqual(10, block.invoke(&block, 3));
}

test "Block.copy / release: context snapshot and heap lifetime" {
    const Context = extern struct { value: i32, pointer: *i32 };
    const Read = Block(Context, fn () i32);
    const callback = struct {
        fn invoke(block: *const Read) callconv(.c) i32 {
            return block.context.value + block.context.pointer.*;
        }
    }.invoke;

    var value: i32 = 10;
    const retained = retain: {
        // The heap copy must also survive the end of the stack block's scope.
        const copied = copy: {
            var block = Read.init(.{ .value = 7, .pointer = &value }, &callback);
            const heap = block.copy().?;
            errdefer heap.release();
            try std.testing.expect(heap != &block);
            block.context.value = 100;
            break :copy heap;
        };
        defer copied.release();

        value = 20;
        try std.testing.expectEqual(7, copied.context.value);
        try std.testing.expectEqual(&value, copied.context.pointer);
        try std.testing.expectEqual(27, copied.invoke(copied));

        const retained = copied.copy().?;
        errdefer retained.release();
        try std.testing.expectEqual(copied, retained);
        break :retain retained;
    };
    defer retained.release();
    // Releasing one ownership must leave the retained heap block usable.
    try std.testing.expectEqual(27, retained.invoke(retained));
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

test "generateFromFnType: return type, implicit argument, parameter order and terminator" {
    const cases = .{
        .{ fn () void, "v@?" },
        .{ fn (i32, f64) i32, "i@?id" },
        .{ fn (i32, *const u8, bool) f64, "d@?i^CB" },
    };
    inline for (cases) |case| {
        const signature = comptime generateFromFnType(case[0]);
        try std.testing.expectEqualStrings(case[1], signature);
        try std.testing.expectEqual(@as(u8, 0), signature.ptr[signature.len]);
    }
}
