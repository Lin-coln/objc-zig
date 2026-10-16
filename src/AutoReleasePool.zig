const std = @import("std");
const objc = @import("root.zig");

pub const AutoReleasePool = opaque {
    const Self = @This();

    pub fn create() *Self {
        return @ptrCast(objc.rt.autoreleasePoolPush());
    }

    pub fn release(self: *Self) void {
        objc.rt.autoreleasePoolPop(self);
    }
};

test "AutoReleasePool: create / release an empty pool" {
    const pool = AutoReleasePool.create();
    defer pool.release();
}

test "AutoReleasePool: nested pools drain independently and retained objects survive" {
    const rt = objc.rt;
    const Probe = struct {
        var deallocations: usize = 0;

        fn dealloc(self: *rt.Object, _: *rt.Sel) callconv(.c) void {
            deallocations += 1;
            rt.msgSendSuper(self, rt.getClass("NSObject").?, void, rt.Sel.registerName("dealloc"), .{});
        }
    };
    const cls = rt.allocateClassPair(rt.getClass("NSObject").?, "ObjcZigAutoReleasePoolTest", 0) orelse return error.ClassAllocFailed;
    defer rt.disposeClassPair(cls);
    try std.testing.expect(cls.addMethod(rt.Sel.registerName("dealloc"), &Probe.dealloc, "v@:"));
    rt.registerClassPair(cls);

    const new = rt.Sel.registerName("new");
    const autorelease = rt.Sel.registerName("autorelease");
    {
        const retained = rt.msgSend(cls, *rt.Object, new, .{});
        defer rt.release(retained);
        {
            const outer = AutoReleasePool.create();
            defer outer.release();

            _ = rt.msgSend(rt.retain(retained), *rt.Object, autorelease, .{});
            const outer_object = rt.msgSend(cls, *rt.Object, new, .{});
            _ = rt.msgSend(outer_object, *rt.Object, autorelease, .{});
            try std.testing.expectEqual(0, Probe.deallocations);

            {
                const inner = AutoReleasePool.create();
                defer inner.release();

                const inner_object = rt.msgSend(cls, *rt.Object, new, .{});
                _ = rt.msgSend(inner_object, *rt.Object, autorelease, .{});
                try std.testing.expectEqual(0, Probe.deallocations);
            }
            try std.testing.expectEqual(1, Probe.deallocations);

            // After the inner pool drains, new autoreleases belong to the outer pool again.
            const later_object = rt.msgSend(cls, *rt.Object, new, .{});
            _ = rt.msgSend(later_object, *rt.Object, autorelease, .{});
            try std.testing.expectEqual(1, Probe.deallocations);
        }
        try std.testing.expectEqual(3, Probe.deallocations);
        try std.testing.expectEqual(cls, retained.getClass());
    }
    try std.testing.expectEqual(4, Probe.deallocations);
}
