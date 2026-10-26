const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run Objective-C tests");

    const objc_abi = blk: {
        const trans = b.addTranslateC(.{
            .root_source_file = b.path("ffi/c.h"),
            .target = target,
            .optimize = optimize,
        });
        const mod = trans.addModule("objc-abi");
        break :blk mod;
    };
    test_step.dependOn(addCompileErrorTests(b, target, optimize, objc_abi));

    const obzc = blk: {
        const opts: std.Build.Module.CreateOptions = .{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "objc-abi", .module = objc_abi },
            },
        };

        const mod = b.addModule("obzc", opts);
        mod.linkSystemLibrary("objc", .{});

        const test_mod = b.createModule(opts);
        test_mod.linkSystemLibrary("objc", .{});
        test_mod.linkFramework("Foundation", .{ .needed = true });

        const tests = b.addTest(.{ .root_module = test_mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);

        break :blk mod;
    };

    const tests = blk: {
        const mod = b.createModule(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "obzc", .module = obzc },
            },
        });

        mod.linkFramework("Foundation", .{ .needed = true });

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
    objc_abi: *std.Build.Module,
) *std.Build.Step {
    const step = b.step("test-compile-errors", "Check compile-time validation errors");
    inline for (@import("compile_test.zig").sources) |source| {
        inline for (source.CompileTestCases) |case| {
            const check = b.addTest(.{
                .name = "compile-test",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("compile_test.zig"),
                    .target = target,
                    .optimize = optimize,
                    .imports = &.{
                        .{ .name = "objc-abi", .module = objc_abi },
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
