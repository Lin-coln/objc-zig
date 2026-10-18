const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const macos = blk: {
        const trans = b.addTranslateC(.{
            .root_source_file = b.path("translate/macos.h"),
            .target = target,
            .optimize = optimize,
        });
        const mod = trans.addModule("abi");
        break :blk mod;
    };

    _ = macos;
}
