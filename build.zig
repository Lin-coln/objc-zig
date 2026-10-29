const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    inline for (.{
        // pkg/*
        "core",
        "ns",
        "sck",
        "mtl",
        "vision",
        // shared/macos
        "macos",
    }) |name| {
        const dep = b.dependency(name, .{ .target = target, .optimize = optimize });
        try b.modules.put(b.graph.arena, name, dep.module(name));
    }
}
