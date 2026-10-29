const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run Vision tests");
    const macos_abi = b.dependency("macos", .{ .target = target, .optimize = optimize }).module("abi");
    const core = b.dependency("core", .{ .target = target, .optimize = optimize }).module("core");
    const ns = b.dependency("ns", .{ .target = target, .optimize = optimize }).module("ns");

    const vision = blk: {
        const opts: std.Build.Module.CreateOptions = .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core },
                .{ .name = "ns", .module = ns },
                .{ .name = "macos/abi", .module = macos_abi },
            },
        };

        const mod = b.addModule("vision", opts);
        mod.linkFramework("Vision", .{ .needed = true });

        const test_mod = b.createModule(opts);
        test_mod.linkFramework("Vision", .{ .needed = true });

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
                .{ .name = "core", .module = core },
                .{ .name = "ns", .module = ns },
                .{ .name = "vision", .module = vision },
                .{ .name = "macos/abi", .module = macos_abi },
            },
        });
        mod.linkFramework("CoreVideo", .{});

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    _ = tests;
}
