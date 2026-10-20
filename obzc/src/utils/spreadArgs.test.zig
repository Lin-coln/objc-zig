const spreadArgs = @import("spreadArgs.zig").spreadArgs;

pub const CompileTestCases = .{
    .{
        .name = "spreadArgs: rejects generic handlers without arity",
        .expected_error = "spreadArgs generic handler requires arity",
    },
    .{
        .name = "spreadArgs: rejects more than fifteen parameters",
        .expected_error = "spreadArgs supports at most 15 parameters",
    },
    .{
        .name = "spreadArgs: rejects generic handlers with C calling convention",
        .expected_error = "spreadArgs generic handler requires the auto calling convention",
    },
    .{
        .name = "spreadArgs: rejects runtime signed to unsigned conversion",
        .expected_error = "expected type 'c_ulong', found 'c_int'",
    },
};

test "spreadArgs: rejects generic handlers without arity" {
    const Static = struct {
        fn call(args: anytype) void {
            _ = args;
        }
    };
    _ = spreadArgs(Static.call, .{});
}

test "spreadArgs: rejects more than fifteen parameters" {
    const Static = struct {
        fn call(args: anytype) void {
            _ = args;
        }
    };
    _ = spreadArgs(Static.call, .{ .arity = 16 });
}

test "spreadArgs: rejects generic handlers with C calling convention" {
    const Static = struct {
        fn call(args: anytype) void {
            _ = args;
        }
    };
    _ = spreadArgs(Static.call, .{ .arity = 1, .convention = .c });
}

test "spreadArgs: rejects runtime signed to unsigned conversion" {
    const Static = struct {
        fn call(args: anytype) c_ulong {
            return args[0];
        }

        noinline fn runtime(value: c_int) c_ulong {
            return spreadArgs(call, .{ .arity = 1 })(value);
        }
    };
    _ = Static.runtime(7);
}
