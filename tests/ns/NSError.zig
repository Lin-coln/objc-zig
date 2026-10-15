const std = @import("std");
const objc = @import("objc");

pub const NSError = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub fn new(domain: [:0]const u8, code: isize) *Self {
        const domain_string = objc.zig.msgSend(
            objc.getClass("NSString").?.alloc(),
            ?*objc.zig.Object,
            objc.zig.Sel.registerName("initWithUTF8String:"),
            .{domain.ptr},
        ).?;
        defer objc.zig.release(domain_string);

        return objc.zig.msgSend(
            objc.getClass("NSError").?.alloc(),
            ?*Self,
            objc.zig.Sel.registerName("initWithDomain:code:userInfo:"),
            .{ domain_string, code, @as(?*objc.zig.Object, null) },
        ).?;
    }

    pub const retain = h.retain;
    pub const release = h.release;

    pub const getCode = h.prop(isize, "code").getter;
    pub const getDomain = h.prop(*objc.zig.Object, "domain").getter;
    pub const getLocalizedDescription = h.prop(*objc.zig.Object, "localizedDescription").getter;

    pub fn log(self: *Self) void {
        std.log.err("NSError domain={s} code={d} {s}", .{
            objc.zig.msgSend(self.getDomain(), [*:0]const u8, objc.zig.Sel.registerName("UTF8String"), .{}),
            self.getCode(),
            objc.zig.msgSend(self.getLocalizedDescription(), [*:0]const u8, objc.zig.Sel.registerName("UTF8String"), .{}),
        });
    }
};

test "NSError: create and read Objective-C properties" {
    const pool = objc.zig.autoreleasePoolPush();
    defer objc.zig.autoreleasePoolPop(pool);

    const err = NSError.new("ObjcZigTestDomain", 42);
    defer err.release();

    try std.testing.expectEqual(42, err.getCode());

    const domain = objc.zig.msgSend(err.getDomain(), [*:0]const u8, objc.zig.Sel.registerName("UTF8String"), .{});
    try std.testing.expectEqualStrings("ObjcZigTestDomain", std.mem.span(domain));

    const description = objc.zig.msgSend(err.getLocalizedDescription(), [*:0]const u8, objc.zig.Sel.registerName("UTF8String"), .{});
    try std.testing.expect(description[0] != 0);
}
