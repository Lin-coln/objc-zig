const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // pkg/*
    inline for (.{ "core", "ns", "sck", "mtl", "vision" }) |name| {
        const dep = b.dependency(name, .{ .target = target, .optimize = optimize });
        try b.modules.put(b.graph.arena, name, dep.module(name));
    }

    {
        const dep = b.dependency("macos", .{ .target = target, .optimize = optimize });
        try b.modules.put(b.graph.arena, "macos", dep.module("abi"));
    }

    // zig build test                 Run tests for every package.
    // zig build test -Dpkg=mtl,sck   Run tests for the selected packages.
    try @import("build/test.zig").addTestStep(b, .{ .target = target, .optimize = optimize });
}
