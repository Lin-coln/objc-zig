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
}
