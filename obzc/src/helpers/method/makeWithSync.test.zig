const Method = @import("root.zig").Method;
const Object = @import("../../rt/Object.zig").Object;

const Helper = struct {
    pub fn call(comptime Return: type, _: [:0]const u8, _: anytype) Return {
        unreachable;
    }
};
const m = Method(Object, Helper);
const InstanceHelper = struct {
    pub fn call(_: *Object, comptime Return: type, _: [:0]const u8, _: anytype) Return {
        unreachable;
    }
};
const instance = Method(Object, InstanceHelper);

pub const CompileTestCases = .{
    .{ .name = "withSync: rejects plain return type", .expected_error = "withSync Shape must return an error union" },
    .{ .name = "withSync: rejects scalar result", .expected_error = "withSync result must be void or an Objective-C object pointer" },
    .{ .name = "withSync: rejects non-object pointer result", .expected_error = "withSync result must be a non-null pointer to an opaque Objective-C object" },
    .{ .name = "withSync: rejects non-function instance shape", .expected_error = "Shape must be a function type" },
    .{ .name = "withSync: rejects generic instance shape", .expected_error = "Shape cannot have generic parameters" },
};

test "withSync: rejects plain return type" {
    _ = m.withSync("complete:", fn () void);
}

test "withSync: rejects scalar result" {
    _ = m.withSync("complete:", fn () anyerror!bool);
}

test "withSync: rejects non-object pointer result" {
    _ = m.withSync("complete:", fn () anyerror!*u8);
}

test "withSync: rejects non-function instance shape" {
    _ = instance.withSync("complete:", u32);
}

test "withSync: rejects generic instance shape" {
    _ = instance.withSync("complete:", fn (anytype) anyerror!void);
}
