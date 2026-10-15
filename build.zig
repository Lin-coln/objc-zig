const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run Objective-C tests");

    const abi = blk: {
        const trans = b.addTranslateC(.{
            .root_source_file = b.path("translate/objc.h"),
            .target = target,
            .optimize = optimize,
        });
        const mod = trans.addModule("objc-abi");
        break :blk mod;
    };

    const objc = blk: {
        const mod = b.addModule("objc", .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "objc-abi", .module = abi },
            },
        });

        mod.linkSystemLibrary("objc", .{});
        mod.linkFramework("Foundation", .{});

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    const objc_tests = blk: {
        const mod = b.createModule(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "objc", .module = objc },
            },
        });

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    _ = objc_tests;
}
