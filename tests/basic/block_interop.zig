const std = @import("std");
const objc = @import("objc").rt;
const c = @import("objc").c;

const Block = objc.Block;
const Object = objc.Object;
const Sel = objc.Sel;

fn numberArray() *Object {
    const NSNumber = objc.class("NSNumber").?;
    var numbers: [3]*Object = .{
        objc.msgSend(NSNumber, ?*Object, Sel.registerName("numberWithInt:"), .{@as(c_int, 30)}).?,
        objc.msgSend(NSNumber, ?*Object, Sel.registerName("numberWithInt:"), .{@as(c_int, 10)}).?,
        objc.msgSend(NSNumber, ?*Object, Sel.registerName("numberWithInt:"), .{@as(c_int, 20)}).?,
    };
    return objc.msgSend(objc.class("NSArray").?, ?*Object, Sel.registerName("arrayWithObjects:count:"), .{ &numbers, @as(usize, numbers.len) }).?;
}

test "NSArray enumeration invokes a Zig Block and honors stop" {
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);
    const array = numberArray();

    // void (^)(id obj, NSUInteger idx, BOOL *stop): sum values and stop after the second element.
    const State = struct { sum: c_int = 0, count: usize = 0 };
    const Enumerate = Block(*State, fn (?*Object, usize, *c.BOOL) void);
    const enumerate = struct {
        fn f(block: *const Enumerate, obj: ?*Object, idx: usize, stop: *c.BOOL) callconv(.c) void {
            block.context.sum += objc.msgSend(obj.?, c_int, Sel.registerName("intValue"), .{});
            block.context.count += 1;
            if (idx == 1) stop.* = c.YES;
        }
    }.f;
    var state: State = .{};
    var enumerate_block = Enumerate.init(&state, &enumerate);
    objc.msgSend(array, void, Sel.registerName("enumerateObjectsUsingBlock:"), .{&enumerate_block});
    try std.testing.expectEqual(2, state.count);
    try std.testing.expectEqual(40, state.sum);
}

test "NSArray sorting invokes a Zig Block comparator" {
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);
    const array = numberArray();

    // NSComparisonResult (^)(id, id)
    const Compare = Block(void, fn (?*Object, ?*Object) isize);
    const compare = struct {
        fn f(_: *const Compare, a: ?*Object, b: ?*Object) callconv(.c) isize {
            return objc.msgSend(a.?, isize, Sel.registerName("compare:"), .{b.?});
        }
    }.f;
    var compare_block = Compare.init({}, &compare);
    const sorted = objc.msgSend(array, ?*Object, Sel.registerName("sortedArrayUsingComparator:"), .{&compare_block}).?;
    const first = objc.msgSend(sorted, ?*Object, Sel.registerName("firstObject"), .{}).?;
    try std.testing.expectEqual(10, objc.msgSend(first, c_int, Sel.registerName("intValue"), .{}));
}
