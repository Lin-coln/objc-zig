const Method = @import("root.zig").Method;
const Object = @import("../../rt/Object.zig").Object;

const Helper = struct {
    pub fn call(comptime Return: type, _: [:0]const u8, _: anytype) Return {
        unreachable;
    }
};
const m = Method(Object, Helper);

pub const CompileTestCases = .{
    .{ .name = "withSync: rejects plain return type", .expected_error = "withSync Shape must return an error union" },
    .{ .name = "withSync: rejects optional object result", .expected_error = "withSync result must be void or an Objective-C object pointer" },
    .{ .name = "withSync: rejects non-object pointer result", .expected_error = "withSync result must be a non-null pointer to an opaque Objective-C object" },
};

test "withSync: rejects plain return type" {
    _ = m.withSync("complete:", fn () void);
}

test "withSync: rejects optional object result" {
    _ = m.withSync("complete:", fn () anyerror!?*Object);
}

test "withSync: rejects non-object pointer result" {
    _ = m.withSync("complete:", fn () anyerror!*u8);
}
