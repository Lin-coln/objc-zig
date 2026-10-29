const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run all project tests");
    const opts = .{ .target = target, .optimize = optimize };

    inline for (.{ "core", "ns", "sck", "mtl", "vision" }) |name| {
        const dependency = b.dependency(name, opts);
        const step = &dependency.builder.top_level_steps.get("test").?.step;
        test_step.dependOn(step);
    }
}
