const initBlockWithContext = @import("initBlockWithContext.zig").initBlockWithContext;

pub const CompileTestCases = .{
    .{ .name = "initBlockWithContext: rejects non-pointer context", .expected_error = "block context must be a single-item pointer" },
    .{ .name = "initBlockWithContext: rejects non-function handler", .expected_error = "block handler must be a function" },
    .{ .name = "initBlockWithContext: rejects missing context parameter", .expected_error = "block handler must take a context pointer as its first parameter" },
    .{ .name = "initBlockWithContext: rejects generic handler", .expected_error = "block handler cannot have anytype or comptime parameters" },
    .{ .name = "initBlockWithContext: rejects mismatched context type", .expected_error = "block handler's first parameter must match the context pointer type" },
    .{ .name = "initBlockWithContext: rejects variadic handler", .expected_error = "block handler cannot have C variadic parameters (...)" },
    .{ .name = "initBlockWithContext: rejects excessive block arguments", .expected_error = "block handler supports at most 12 block arguments, excluding context" },
};

test "initBlockWithContext: rejects non-pointer context" {
    const Handler = struct {
        fn call(_: u32) void {}
    };
    _ = initBlockWithContext(@as(u32, 7), Handler.call);
}

test "initBlockWithContext: rejects non-function handler" {
    var context: i32 = 0;
    _ = initBlockWithContext(&context, 7);
}

test "initBlockWithContext: rejects missing context parameter" {
    const Handler = struct {
        fn call() void {}
    };
    var context: i32 = 0;
    _ = initBlockWithContext(&context, Handler.call);
}

test "initBlockWithContext: rejects generic handler" {
    const Handler = struct {
        fn call(_: *i32, _: anytype) void {}
    };
    var context: i32 = 0;
    _ = initBlockWithContext(&context, Handler.call);
}

test "initBlockWithContext: rejects mismatched context type" {
    const Handler = struct {
        fn call(_: *u32) void {}
    };
    var context: i32 = 0;
    _ = initBlockWithContext(&context, Handler.call);
}

test "initBlockWithContext: rejects variadic handler" {
    const Handler = struct {
        extern fn call(_: *i32, ...) void;
    };
    var context: i32 = 0;
    _ = initBlockWithContext(&context, Handler.call);
}

test "initBlockWithContext: rejects excessive block arguments" {
    const Handler = struct {
        fn call(_: *i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32) void {}
    };
    var context: i32 = 0;
    _ = initBlockWithContext(&context, Handler.call);
}
