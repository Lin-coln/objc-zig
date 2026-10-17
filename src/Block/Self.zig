const Root = @This();
const std = @import("std");
const builtin = @import("builtin");
const c = @import("../c.zig").c;
const Object = @import("../rt/Object.zig").Object;
const Class = @import("../rt/Class.zig").Class;
const Sel = @import("../rt/Sel.zig").Sel;
const Signature = @import("signature.zig");

/// An Objective-C block literal (Apple Block ABI) whose `invoke` has the parameters of `Function`,
/// preceded by a pointer to the block itself. `context` is copied bytewise when the block is copied to the heap.
/// `*Object` and `?*Object` values in it, either `context` itself or fields of an `extern struct` context,
/// are also retained by the heap copy and released when it is freed. Nothing else is retained.
/// The descriptor carries the Objective-C type encoding of `invoke` as the block's signature.
pub fn Block(comptime Context: type, comptime Function: type) type {
    const fn_info = @typeInfo(Function).@"fn";
    const Return = fn_info.return_type.?;
    const signature = comptime Signature.generateFromFnType(Function);
    const flags = comptime Literal.getFlags(Context, Function);

    return extern struct {
        isa: ?*anyopaque,
        flags: c_int,
        reserved: c_int,
        invoke: *const Fn,
        descriptor: *const Descriptor,
        context: Context,

        const Self = @This();

        pub const Fn = blk: {
            var param_types: [fn_info.param_types.len + 1]type = undefined;
            param_types[0] = *const Self;
            for (fn_info.param_types, 1..) |T, i| param_types[i] = T.?;
            break :blk @Fn(&param_types, &@splat(.{}), Return, .{ .@"callconv" = .c });
        };

        const Descriptor = Root.Literal.Descriptor(Context, Self);
        const block_descriptor: Descriptor = .init(signature);
        /// Creates a stack block. Objective-C copies it to the heap if it keeps it beyond the call.
        pub fn init(context: Context, invoke: *const Fn) Self {
            return .{
                .isa = &c._NSConcreteStackBlock,
                .flags = flags,
                .reserved = 0,
                .invoke = invoke,
                .descriptor = &block_descriptor,
                .context = context,
            };
        }

        /// Copies a stack block to the heap, or retains a block that is already there. Must be balanced with `release`.
        pub fn copy(self: *const Self) ?*Self {
            return @ptrCast(@alignCast(c._Block_copy(self)));
        }

        pub fn release(self: *const Self) void {
            c._Block_release(self);
        }
    };
}

fn isObject(comptime T: type) bool {
    return T == *Object or T == ?*Object;
}

/// Whether `Context` is an object or an `extern struct` with object fields.
fn hasObject(comptime Context: type) bool {
    return isObject(Context) or switch (@typeInfo(Context)) {
        .@"struct" => |info| for (info.field_types) |T| {
            if (isObject(T)) break true;
        } else false,
        else => false,
    };
}

const Literal = struct {
    // From the Apple Block ABI; Block.h does not declare them.
    const BLOCK_HAS_COPY_DISPOSE = 1 << 25;
    const BLOCK_HAS_STRET = 1 << 29;
    const BLOCK_HAS_SIGNATURE = 1 << 30;
    const BLOCK_FIELD_IS_OBJECT = 3;

    /// The block flags describing the descriptor of a block capturing `Context` whose `invoke` has the parameters of `Function`.
    fn getFlags(comptime Context: type, comptime Function: type) c_int {
        const Return = @typeInfo(Function).@"fn".return_type.?;
        // Same rule as `msgSend`: only x86_64 returns large structs through a hidden pointer argument.
        const stret = builtin.target.cpu.arch == .x86_64 and @typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16;
        return BLOCK_HAS_SIGNATURE |
            (if (hasObject(Context)) BLOCK_HAS_COPY_DISPOSE else 0) |
            (if (stret) BLOCK_HAS_STRET else 0);
    }

    /// The descriptor of the block literal type `BlockType` capturing `Context`. If `Context` holds objects,
    /// it carries the copy and dispose helpers that retain and release them.
    fn Descriptor(comptime Context: type, comptime BlockType: type) type {
        return if (hasObject(Context)) extern struct {
            reserved: c_ulong,
            size: c_ulong,
            copy_helper: *const fn (dst: *BlockType, src: *const BlockType) callconv(.c) void,
            dispose_helper: *const fn (src: *const BlockType) callconv(.c) void,
            signature: [*:0]const u8,

            fn init(signature: [*:0]const u8) @This() {
                return .{
                    .reserved = 0,
                    .size = @sizeOf(BlockType),
                    .copy_helper = &copyHelper,
                    .dispose_helper = &disposeHelper,
                    .signature = signature,
                };
            }

            /// Called by `_Block_copy` on the new heap block after copying `src` into it bytewise.
            fn copyHelper(dst: *BlockType, src: *const BlockType) callconv(.c) void {
                if (comptime isObject(Context)) {
                    c._Block_object_assign(@ptrCast(&dst.context), src.context, BLOCK_FIELD_IS_OBJECT);
                } else inline for (@typeInfo(Context).@"struct".field_names, @typeInfo(Context).@"struct".field_types) |name, T| {
                    if (comptime isObject(T)) c._Block_object_assign(@ptrCast(&@field(dst.context, name)), @field(src.context, name), BLOCK_FIELD_IS_OBJECT);
                }
            }

            /// Called by the last `_Block_release` of a heap block before freeing it.
            fn disposeHelper(src: *const BlockType) callconv(.c) void {
                if (comptime isObject(Context)) {
                    c._Block_object_dispose(src.context, BLOCK_FIELD_IS_OBJECT);
                } else inline for (@typeInfo(Context).@"struct".field_names, @typeInfo(Context).@"struct".field_types) |name, T| {
                    if (comptime isObject(T)) c._Block_object_dispose(@field(src.context, name), BLOCK_FIELD_IS_OBJECT);
                }
            }
        } else extern struct {
            reserved: c_ulong,
            size: c_ulong,
            signature: [*:0]const u8,

            fn init(signature: [*:0]const u8) @This() {
                return .{ .reserved = 0, .size = @sizeOf(BlockType), .signature = signature };
            }
        };
    }
};

test "Block: invoke directly and after copy / release" {
    const Add = Block(i32, fn (i32, i32) i32);
    const add = struct {
        fn f(block: *const Add, a: i32, b: i32) callconv(.c) i32 {
            return block.context + a + b;
        }
    }.f;

    var block = Add.init(100, &add);
    try std.testing.expectEqual(103, block.invoke(&block, 1, 2));

    const copied = block.copy().?;
    defer copied.release();
    try std.testing.expect(copied != &block);
    try std.testing.expectEqual(103, copied.invoke(copied, 1, 2));

    // Copying a heap block retains it instead of allocating a new one.
    const retained = copied.copy().?;
    defer retained.release();
    try std.testing.expectEqual(copied, retained);
}

test "Block: heap copy retains *Object in context and releases it when freed" {
    const rt = @import("../rt/root.zig");
    const obj = rt.msgSend(rt.getClass("NSObject").?, ?*Object, Sel.registerName("new"), .{}).?;
    defer rt.release(obj);

    // The context itself is an object.
    const Direct = Block(*Object, fn () void);
    const direct_invoke = struct {
        fn f(_: *const Direct) callconv(.c) void {}
    }.f;
    const direct = Direct.init(obj, &direct_invoke);
    try std.testing.expectEqual(1, rt.msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
    const direct_copy = direct.copy().?;
    try std.testing.expectEqual(obj, direct_copy.context);
    try std.testing.expectEqual(2, rt.msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
    direct_copy.release();
    try std.testing.expectEqual(1, rt.msgSend(obj, usize, Sel.registerName("retainCount"), .{}));

    // Object fields of an extern struct context; other fields are only copied.
    const Captures = extern struct { first: *Object, count: i32, second: ?*Object };
    const Fields = Block(Captures, fn () void);
    const fields_invoke = struct {
        fn f(_: *const Fields) callconv(.c) void {}
    }.f;
    const fields = Fields.init(.{ .first = obj, .count = 7, .second = obj }, &fields_invoke);
    const fields_copy = fields.copy().?;
    try std.testing.expectEqual(7, fields_copy.context.count);
    try std.testing.expectEqual(3, rt.msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
    fields_copy.release();
    try std.testing.expectEqual(1, rt.msgSend(obj, usize, Sel.registerName("retainCount"), .{}));
}

test "Block: signature and flags" {
    const rt = @import("../rt/root.zig");
    const Point = extern struct { x: f64, y: f64 };
    const Big = extern struct { a: u64, b: u64, c: u64 };
    const cases = .{
        .{ Block(i32, fn (i32, i32) i32), "i@?ii", 3 },
        .{ Block(void, fn (?*Object, usize, *c.BOOL) void), "v@?@" ++ (if (@sizeOf(usize) == 8) "Q" else "I") ++ "^c", 4 },
        .{ Block(*Object, fn (Point, [*:0]const u8, *Class, *Sel) Point), "{Point=dd}@?{Point=dd}*#:", 5 },
        .{ Block(void, fn (*const Point, ?*const fn () callconv(.c) void, [4]u8) void), "v@?^{Point}^?[4C]", 4 },
    };
    const NSMethodSignature = rt.getClass("NSMethodSignature").?;
    inline for (cases) |case| {
        const signature = std.mem.span(case[0].block_descriptor.signature);
        try std.testing.expectEqualStrings(case[1], signature);
        // Foundation's own type encoding parser must accept the signature.
        const parsed = rt.msgSend(NSMethodSignature, ?*Object, Sel.registerName("signatureWithObjCTypes:"), .{signature.ptr}).?;
        try std.testing.expectEqual(case[2], rt.msgSend(parsed, usize, Sel.registerName("numberOfArguments"), .{}));
        const first: [*:0]const u8 = rt.msgSend(parsed, [*:0]const u8, Sel.registerName("getArgumentTypeAtIndex:"), .{@as(usize, 0)});
        try std.testing.expectEqualStrings("@?", std.mem.span(first));
    }

    try std.testing.expectEqual(Literal.BLOCK_HAS_SIGNATURE, comptime Literal.getFlags(i32, fn () void));
    try std.testing.expectEqual(Literal.BLOCK_HAS_SIGNATURE | Literal.BLOCK_HAS_COPY_DISPOSE, comptime Literal.getFlags(*Object, fn () void));
    const big_flags = comptime Literal.getFlags(void, fn () Big);
    try std.testing.expectEqual(builtin.target.cpu.arch == .x86_64, big_flags & Literal.BLOCK_HAS_STRET != 0);
}
