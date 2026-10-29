const std = @import("std");
const ffi = @import("../../ffi/root.zig");
const encodeType = @import("../../encode/root.zig").encodeType;
const c = ffi.c;
const Class = ffi.Class;

pub fn ivar(comptime T: type) type {
    _ = T;

    return struct {
        pub fn addIvar(
            cls: *Class,
            comptime name: [:0]const u8,
            comptime Type: type,
        ) !void {
            const done = c.class_addIvar(
                @ptrCast(cls),
                name,
                @sizeOf(Type),
                comptime std.math.log2_int(usize, @alignOf(Type)),
                comptime encodeType(Type),
            );
            if (done == c.YES) return;
            return error.AddIvarFailed;
        }
    };
}

test "ClassFactory.ivar.addIvar: derives size and alignment from the value type and maps failure" {
    const Payload = extern struct { first: u64, second: u64 };
    const raw = c.objc_allocateClassPair(c.objc_getClass("NSObject").?, "ObzcFactoryIvarProbe", 0).?;
    defer c.objc_disposeClassPair(raw);
    const cls: *Class = @ptrCast(raw);
    const ivars = ivar(opaque {});
    const base_size = c.class_getInstanceSize(raw);
    try ivars.addIvar(cls, "_prefix", u8);
    try ivars.addIvar(cls, "_payload", Payload);
    try ivars.addIvar(cls, "_tail", u8);
    try std.testing.expectError(error.AddIvarFailed, ivars.addIvar(cls, "_payload", Payload));
    c.objc_registerClassPair(raw);

    const payload = c.class_getInstanceVariable(raw, "_payload").?;
    const tail = c.class_getInstanceVariable(raw, "_tail").?;
    const payload_offset = std.mem.alignForward(usize, base_size + 1, @alignOf(Payload));
    try std.testing.expectEqual(@as(isize, @intCast(payload_offset)), c.ivar_getOffset(payload));
    try std.testing.expectEqual(@as(isize, @intCast(payload_offset + @sizeOf(Payload))), c.ivar_getOffset(tail));
    try std.testing.expectEqualStrings("{Payload=QQ}", std.mem.span(c.ivar_getTypeEncoding(payload)));
}
