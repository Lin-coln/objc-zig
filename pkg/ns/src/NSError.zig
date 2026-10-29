const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const Metadata = core.Metadata;
const Object = core.ffi.Object;
const NSString = @import("NSString.zig").NSString;

pub const NSError = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub fn init(domain_name: []const u8, error_code: isize) ?*Self {
        const domain_string = NSString.init(domain_name) orelse return null;
        defer domain_string.release();

        const allocated: *Self = h.cls.alloc();
        return h.call(
            allocated,
            ?*Self,
            "initWithDomain:code:userInfo:",
            .{ domain_string, error_code, @as(?*Object, null) },
        );
    }

    pub const code = h.prop("code", isize).getter;
    pub const domain = h.prop("domain", *NSString).getter;
    pub const localizedDescription = h.prop("localizedDescription", *NSString).getter;

    pub fn log(self: *Self) void {
        if (builtin.is_test) return;

        std.log.err("NSError domain={s} code={d} {s}", .{
            self.domain().utf8String(),
            self.code(),
            self.localizedDescription().utf8String(),
        });
    }
};

test "NSError: create and read Objective-C properties" {
    const pool = core.AutoReleasePool.create();
    defer pool.release();

    const err = NSError.init("ObjcZigTestDomain", 42).?;
    defer err.release();

    try std.testing.expectEqual(42, err.code());

    try std.testing.expectEqualStrings("ObjcZigTestDomain", err.domain().utf8String());

    try std.testing.expect(err.localizedDescription().length() != 0);

    const invalid = [_]u8{0xff};
    try std.testing.expect(NSError.init(&invalid, 42) == null);
}

test "NSError: log is silent during tests" {
    const err = NSError.init("ObjcZigTestDomain", 42).?;
    defer err.release();

    err.log();
}
