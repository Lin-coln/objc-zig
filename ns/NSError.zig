const std = @import("std");
const objc = @import("objc");
const NSString = @import("NSString.zig").NSString;

pub const NSError = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub fn init(domain: []const u8, code: isize) ?*Self {
        const domain_string = NSString.init(domain) orelse return null;
        defer domain_string.release();

        const allocated: *Self = @ptrCast(objc.getClass("NSError").?.alloc());
        return h.msgSend(
            allocated,
            ?*Self,
            "initWithDomain:code:userInfo:",
            .{ domain_string, code, @as(?*objc.rt.Object, null) },
        );
    }

    pub const getCode = h.prop(isize, "code").getter;
    pub const getDomain = h.prop(*NSString, "domain").getter;
    pub const getLocalizedDescription = h.prop(*NSString, "localizedDescription").getter;

    pub fn log(self: *Self) void {
        std.log.err("NSError domain={s} code={d} {s}", .{
            self.getDomain().getUTF8String(),
            self.getCode(),
            self.getLocalizedDescription().getUTF8String(),
        });
    }
};

test "NSError: create and read Objective-C properties" {
    const pool = objc.rt.autoreleasePoolPush();
    defer objc.rt.autoreleasePoolPop(pool);

    const err = NSError.init("ObjcZigTestDomain", 42).?;
    defer err.release();

    try std.testing.expectEqual(42, err.getCode());

    try std.testing.expectEqualStrings("ObjcZigTestDomain", err.getDomain().getUTF8String());

    try std.testing.expect(err.getLocalizedDescription().getLength() != 0);

    const invalid = [_]u8{0xff};
    try std.testing.expect(NSError.init(&invalid, 42) == null);
}
