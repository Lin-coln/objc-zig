const make = @import("makeWithSync.zig").makeWithSync;
const Object = @import("../../ffi/root.zig").Object;

const Helper = struct {
    pub fn call(comptime Return: type, _: [:0]const u8, _: anytype) Return {
        unreachable;
    }
};

pub const CompileTestCases = .{
    .{ .name = "helpers.withSync: rejects plain return type", .expected_error = "withSync Shape must return an error union" },
    .{ .name = "helpers.withSync: rejects optional object result", .expected_error = "withSync result must be void or an Objective-C object pointer" },
    .{ .name = "helpers.withSync: rejects non-object pointer result", .expected_error = "withSync result must be a non-null pointer to an opaque Objective-C object" },
};

test "helpers.withSync: rejects plain return type" {
    _ = make(null, Helper.call, "complete:", fn () void);
}

test "helpers.withSync: rejects optional object result" {
    _ = make(null, Helper.call, "complete:", fn () anyerror!?*Object);
}

test "helpers.withSync: rejects non-object pointer result" {
    _ = make(null, Helper.call, "complete:", fn () anyerror!*u8);
}
