const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run Foundation tests");
    const core = b.dependency("core", .{ .target = target, .optimize = optimize }).module("core");
    test_step.dependOn(addCompileErrorTests(b, target, optimize, core));

    const ns = blk: {
        const mod = b.addModule("obzc-ns", .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core },
            },
        });

        mod.linkFramework("Foundation", .{ .needed = true });

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    const tests = blk: {
        const mod = b.createModule(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core },
                .{ .name = "obzc-ns", .module = ns },
            },
        });

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    _ = tests;
}

fn addCompileErrorTests(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    core: *std.Build.Module,
) *std.Build.Step {
    const step = b.step("test-compile-errors", "Check compile-time validation errors");
    inline for (@import("src/compile_test.zig").sources) |source| {
        inline for (source.CompileTestCases) |case| {
            const check = b.addTest(.{
                .name = "compile-test",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/compile_test.zig"),
                    .target = target,
                    .optimize = optimize,
                    .imports = &.{
                        .{ .name = "core", .module = core },
                    },
                }),
                .filters = &.{case.name},
            });
            check.step.name = case.name;
            check.expect_errors = .{ .contains = case.expected_error };
            _ = check.getEmittedBin();
            step.dependOn(&check.step);
        }
    }
    return step;
}
