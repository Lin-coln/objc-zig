const initWithContext = @import("block.zig").initWithContext;

pub const CompileTestCases = .{
    .{ .name = "initWithContext: rejects non-pointer context", .expected_error = "block context must be a single-item pointer" },
    .{ .name = "initWithContext: rejects non-function handler", .expected_error = "block handler must be a function" },
    .{ .name = "initWithContext: rejects missing context parameter", .expected_error = "block handler must take a context pointer as its first parameter" },
    .{ .name = "initWithContext: rejects generic handler", .expected_error = "block handler cannot have anytype or comptime parameters" },
    .{ .name = "initWithContext: rejects mismatched context type", .expected_error = "block handler's first parameter must match the context pointer type" },
    .{ .name = "initWithContext: rejects variadic handler", .expected_error = "block handler cannot have C variadic parameters (...)" },
    .{ .name = "initWithContext: rejects excessive block arguments", .expected_error = "block handler supports at most 12 block arguments, excluding context" },
};

test "initWithContext: rejects non-pointer context" {
    const Handler = struct {
        fn call(_: u32) void {}
    };
    _ = initWithContext(@as(u32, 7), Handler.call);
}

test "initWithContext: rejects non-function handler" {
    var context: i32 = 0;
    _ = initWithContext(&context, 7);
}

test "initWithContext: rejects missing context parameter" {
    const Handler = struct {
        fn call() void {}
    };
    var context: i32 = 0;
    _ = initWithContext(&context, Handler.call);
}

test "initWithContext: rejects generic handler" {
    const Handler = struct {
        fn call(_: *i32, _: anytype) void {}
    };
    var context: i32 = 0;
    _ = initWithContext(&context, Handler.call);
}

test "initWithContext: rejects mismatched context type" {
    const Handler = struct {
        fn call(_: *u32) void {}
    };
    var context: i32 = 0;
    _ = initWithContext(&context, Handler.call);
}

test "initWithContext: rejects variadic handler" {
    const Handler = struct {
        extern fn call(_: *i32, ...) void;
    };
    var context: i32 = 0;
    _ = initWithContext(&context, Handler.call);
}

test "initWithContext: rejects excessive block arguments" {
    const Handler = struct {
        fn call(_: *i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32) void {}
    };
    var context: i32 = 0;
    _ = initWithContext(&context, Handler.call);
}
