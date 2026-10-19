const NSNumber = @import("NSNumber.zig").NSNumber;

pub const CompileTestCases = .{
    .{
        .name = "NSNumber.init: rejects unsupported value types",
        .expected_error = "NSNumber.init supports only isize, f64, and bool",
    },
    .{
        .name = "NSNumber.as: rejects unsupported result types",
        .expected_error = "NSNumber.as supports only isize, f64, and bool",
    },
};

test "NSNumber.init: rejects unsupported value types" {
    _ = NSNumber.init(u32, 42);
}

test "NSNumber.as: rejects unsupported result types" {
    const number: *NSNumber = undefined;
    _ = number.as(u32);
}
