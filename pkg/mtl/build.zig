const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run Metal tests");
    const macos_abi = b.dependency("macos", .{ .target = target, .optimize = optimize }).module("abi");
    const obzc = b.dependency("obzc", .{ .target = target, .optimize = optimize }).module("obzc");
    const ns = b.dependency("ns", .{ .target = target, .optimize = optimize }).module("obzc-ns");

    const mtl_abi = blk: {
        const trans = b.addTranslateC(.{
            .root_source_file = b.path("translate/metal.h"),
            .target = target,
            .optimize = optimize,
        });
        const mod = trans.createModule();
        break :blk mod;
    };

    const mtl = blk: {
        const mod = b.addModule("obzc-mtl", .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "obzc", .module = obzc },
                .{ .name = "obzc-ns", .module = ns },
                .{ .name = "macos/abi", .module = macos_abi },
                .{ .name = "mtl-abi", .module = mtl_abi },
            },
        });

        mod.linkFramework("Metal", .{ .needed = true });

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
                .{ .name = "obzc", .module = obzc },
                .{ .name = "obzc-ns", .module = ns },
                .{ .name = "obzc-mtl", .module = mtl },
                .{ .name = "macos/abi", .module = macos_abi },
            },
        });

        mod.linkFramework("CoreVideo", .{});
        mod.linkFramework("IOSurface", .{});

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    _ = tests;
}
