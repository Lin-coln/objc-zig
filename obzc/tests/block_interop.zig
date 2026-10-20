const std = @import("std");
const obzc = @import("obzc");
const rt = obzc.rt;
const c = obzc.c;

const Block = obzc.Block;
const block = obzc.helpers.block;
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
    const expected = [_]c_int{ 10, 20, 30 };
    try std.testing.expectEqual(expected.len, rt.msgSend(sorted, usize, Sel.registerName("count"), .{}));
    for (expected, 0..) |value, index| {
        const number = rt.msgSend(sorted, ?*Object, Sel.registerName("objectAtIndex:"), .{index}).?;
        try std.testing.expectEqual(value, rt.msgSend(number, c_int, Sel.registerName("intValue"), .{}));
    }
}

test "NSBlockOperation copies a Zig callback and invokes it after registration returns" {
    const NSBlockOperation = opaque {
        const h = obzc.helpers.Object(@This());

        pub const new = h.cls.new;
        pub const release = h.release;
        pub const addExecutionBlock = h.m.withCallback("addExecutionBlock:", fn (fn () void) void);
        pub const start = h.m.of("start", fn () void);
    };
    const State = struct { value: i32 = 7, observed: i32 = 0, calls: usize = 0 };
    const Callback = struct {
        noinline fn register(operation: *NSBlockOperation, state: *State) void {
            // Foundation must copy the helper's stack block before this call returns.
            operation.addExecutionBlock(state, complete);
        }

        fn complete(state: *State) void {
            state.observed = state.value;
            state.calls += 1;
        }
    };

    const pool = rt.autoreleasePoolPush();
    defer rt.autoreleasePoolPop(pool);
    var state: State = .{};
    const operation = NSBlockOperation.new();
    defer operation.release();

    Callback.register(operation, &state);
    try std.testing.expectEqual(0, state.calls);
    state.value = 19;

    operation.start();
    try std.testing.expectEqual(1, state.calls);
    try std.testing.expectEqual(19, state.observed);
}
