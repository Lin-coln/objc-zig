const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run Objective-C tests");

    const macos = blk: {
        const trans = b.addTranslateC(.{
            .root_source_file = b.path("translate/macos.h"),
            .target = target,
            .optimize = optimize,
        });
        const mod = trans.addModule("macos");
        break :blk mod;
    };

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
        const options: std.Build.Module.CreateOptions = .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "objc-abi", .module = abi },
            },
        };

        const mod = b.addModule("objc", options);
        mod.linkSystemLibrary("objc", .{});

        const test_mod = b.createModule(options);
        test_mod.linkSystemLibrary("objc", .{});
        test_mod.linkFramework("Foundation", .{ .needed = true });

        const tests = b.addTest(.{ .root_module = test_mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    const ns = blk: {
        const mod = b.addModule("objc/ns", .{
            .root_source_file = b.path("ns/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "objc", .module = objc },
            },
        });

        mod.linkFramework("Foundation", .{ .needed = true });

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
                .{ .name = "objc/ns", .module = ns },
                .{ .name = "macos", .module = macos },
            },
        });

        mod.linkFramework("ScreenCaptureKit", .{});
        mod.linkFramework("CoreGraphics", .{});

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    _ = objc_tests;
}
