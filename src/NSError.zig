const std = @import("std");
const objc = @import("root.zig");

pub const NSError = opaque {
    const Self = @This();
    const h = objc.Object.Helpers(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    const getCode = h.prop(isize, "code").getter;
    const getDomain = h.prop(*objc.zig.Object, "domain").getter;
    const getLocalizedDescription = h.prop(*objc.zig.Object, "localizedDescription").getter;

    pub fn log(self: *Self) void {
        std.log.err("NSError domain={s} code={d} {s}", .{
            objc.zig.msgSend(self.getDomain(), [*:0]const u8, objc.zig.Sel.registerName("UTF8String"), .{}),
            self.getCode(),
            objc.zig.msgSend(self.getLocalizedDescription(), [*:0]const u8, objc.zig.Sel.registerName("UTF8String"), .{}),
        });
    }
};
