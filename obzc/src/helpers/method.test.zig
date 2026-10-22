const Method = @import("method.zig").Method;
const Object = @import("../rt/Object.zig").Object;

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
    .{ .name = "of: rejects non-function shape", .expected_error = "Shape must be a function type" },
    .{ .name = "of: rejects generic shape", .expected_error = "Shape must have fixed, non-generic parameters" },
    .{ .name = "withCallback: rejects missing block parameter", .expected_error = "withCallback Shape must end with a block function type" },
    .{ .name = "withCallback: rejects non-function block parameter", .expected_error = "withCallback Shape must end with a block function type" },
    .{ .name = "withCallback: rejects method return values", .expected_error = "withCallback Shape must return void" },
    .{ .name = "withCallback: rejects generic block parameters", .expected_error = "withCallback requires fixed, non-generic block parameters" },
    .{ .name = "withSync: rejects plain return type", .expected_error = "withSync Shape must return an error union" },
    .{ .name = "withSync: rejects scalar result", .expected_error = "withSync result must be void or an Objective-C object pointer" },
    .{ .name = "withSync: rejects non-object pointer result", .expected_error = "withSync result must be a non-null pointer to an opaque Objective-C object" },
    .{ .name = "withSync: rejects non-function instance shape", .expected_error = "withSync Shape must be a function type" },
    .{ .name = "withSync: rejects generic instance shape", .expected_error = "withSync Shape must have fixed, non-generic parameters" },
};

test "of: rejects non-function shape" {
    _ = m.of("value", u32);
}

test "of: rejects generic shape" {
    _ = m.of("value:", fn (anytype) void);
}

test "withCallback: rejects missing block parameter" {
    _ = m.withCallback("complete:", fn () void);
}

test "withCallback: rejects non-function block parameter" {
    _ = m.withCallback("complete:", fn (u32) void);
}

test "withCallback: rejects method return values" {
    _ = m.withCallback("complete:", fn (fn () void) bool);
}

test "withCallback: rejects generic block parameters" {
    _ = m.withCallback("complete:", fn (fn (anytype) void) void);
}

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
