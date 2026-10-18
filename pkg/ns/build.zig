const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run Foundation tests");
    const objc = b.dependency("objc", .{ .target = target, .optimize = optimize }).module("objc");

    const ns = blk: {
        const mod = b.addModule("obzc-ns", .{
            .root_source_file = b.path("src/root.zig"),
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

    _ = ns;
}
