const std = @import("std");
const rt = @import("objc").rt;
const c = @import("objc").c;

const Block = @import("objc").Block;
const block = @import("objc").helpers.block;
const Object = rt.Object;
const Sel = rt.Sel;

fn numberArray() *Object {
    const NSNumber = rt.getClass("NSNumber").?;
    var numbers: [3]*Object = .{
        rt.msgSend(NSNumber, ?*Object, Sel.registerName("numberWithInt:"), .{@as(c_int, 30)}).?,
        rt.msgSend(NSNumber, ?*Object, Sel.registerName("numberWithInt:"), .{@as(c_int, 10)}).?,
        rt.msgSend(NSNumber, ?*Object, Sel.registerName("numberWithInt:"), .{@as(c_int, 20)}).?,
    };
    return rt.msgSend(rt.getClass("NSArray").?, ?*Object, Sel.registerName("arrayWithObjects:count:"), .{ &numbers, @as(usize, numbers.len) }).?;
}

test "NSArray enumeration invokes a Zig Block and honors stop" {
    const pool = rt.autoreleasePoolPush();
    defer rt.autoreleasePoolPop(pool);
    const array = numberArray();

    // void (^)(id obj, NSUInteger idx, BOOL *stop): sum values and stop after the second element.
    const State = struct { sum: c_int = 0, count: usize = 0 };
    var state: State = .{};
    var enumerate = block.initWithContext(&state, struct {
        fn f(s: *State, obj: ?*Object, idx: usize, stop: *c.BOOL) void {
            s.sum += rt.msgSend(obj.?, c_int, Sel.registerName("intValue"), .{});
            s.count += 1;
            if (idx == 1) stop.* = c.YES;
        }
    }.f);
    rt.msgSend(array, void, Sel.registerName("enumerateObjectsUsingBlock:"), .{&enumerate});
    try std.testing.expectEqual(2, state.count);
    try std.testing.expectEqual(40, state.sum);
}

test "NSArray sorting invokes a Zig Block comparator" {
    const pool = rt.autoreleasePoolPush();
    defer rt.autoreleasePoolPop(pool);
    const array = numberArray();

    // NSComparisonResult (^)(id, id)
    const Compare = Block(void, fn (?*Object, ?*Object) isize);
    const compare = struct {
        fn f(_: *const Compare, a: ?*Object, b: ?*Object) callconv(.c) isize {
            return rt.msgSend(a.?, isize, Sel.registerName("compare:"), .{b.?});
        }
    }.f;
    var compare_block = Compare.init({}, &compare);
    const sorted = rt.msgSend(array, ?*Object, Sel.registerName("sortedArrayUsingComparator:"), .{&compare_block}).?;
    const first = rt.msgSend(sorted, ?*Object, Sel.registerName("firstObject"), .{}).?;
    try std.testing.expectEqual(10, rt.msgSend(first, c_int, Sel.registerName("intValue"), .{}));
}
