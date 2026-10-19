const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run ScreenCaptureKit tests");
    const macos_abi = b.dependency("macos", .{ .target = target, .optimize = optimize }).module("abi");
    const obzc = b.dependency("obzc", .{ .target = target, .optimize = optimize }).module("obzc");
    const ns = b.dependency("ns", .{ .target = target, .optimize = optimize }).module("obzc-ns");

    const sck = blk: {
        const opts: std.Build.Module.CreateOptions = .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "obzc", .module = obzc },
                .{ .name = "obzc-ns", .module = ns },
                .{ .name = "macos/abi", .module = macos_abi },
            },
        };

        const mod = b.addModule("obzc-sck", opts);
        mod.linkFramework("ScreenCaptureKit", .{ .needed = true });

        const test_mod = b.createModule(opts);
        test_mod.linkFramework("ScreenCaptureKit", .{ .needed = true });
        test_mod.linkFramework("CoreGraphics", .{});
        test_mod.linkFramework("CoreMedia", .{});

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
                .{ .name = "obzc-sck", .module = sck },
                .{ .name = "macos/abi", .module = macos_abi },
            },
        });

        mod.linkFramework("CoreGraphics", .{});

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    _ = tests;
}
