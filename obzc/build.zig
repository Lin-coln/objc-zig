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

    const obzc = blk: {
        const options: std.Build.Module.CreateOptions = .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "objc-abi", .module = abi },
            },
        };

        const mod = b.addModule("obzc", options);
        mod.linkSystemLibrary("objc", .{});

        const test_mod = b.createModule(options);
        test_mod.linkSystemLibrary("objc", .{});
        test_mod.linkFramework("Foundation", .{ .needed = true });

        const tests = b.addTest(.{ .root_module = test_mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);

        // Match the diagnostic's first line; details may change independently.
        const error_cases = .{
            .{ "integer", "u7" },
            .{ "zero_integer", "u0" },
            .{ "float", "f16" },
            .{ "vector", "@Vector(2, f32)" },
            .{ "auto_struct", "struct Auto" },
            .{ "auto_struct_pointer", "struct Auto" },
            .{ "plain_union", "union Plain" },
            .{ "packed_union", "union Packed" },
            .{ "union_pointer", "union Plain" },
            .{ "slice", "slice of u8" },
            .{ "optional_value", "?u32" },
            .{ "optional_slice", "?[]const u8" },
            .{ "optional_c_pointer", "?[*c]u8" },
            .{ "optional_allowzero", "?*allowzero i32" },
            .{ "nested_optional", "??*i32" },
            .{ "array_element", "?u32" },
            .{ "struct_alignment_lowered", "struct Lowered" },
            .{ "struct_alignment_raised", "struct Raised" },
            .{ "union_alignment", "union AlignedUnion" },
            .{ "nested_alignment", "struct Lowered" },
        };
        inline for (error_cases) |case| {
            const case_options = b.addOptions();
            case_options.addOption([]const u8, "name", case[0]);
            const fixture = b.createModule(.{
                .root_source_file = b.path("tests/block/encode_errors.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "obzc", .module = mod },
                    .{ .name = "case", .module = case_options.createModule() },
                },
            });
            const failure = b.addObject(.{
                .name = b.fmt("encode-error-{s}", .{case[0]}),
                .root_module = fixture,
            });
            failure.expect_errors = .{ .contains = b.fmt("cannot encode {s}:", .{case[1]}) };
            test_step.dependOn(&failure.step);
        }
        break :blk mod;
    };

    const obzc_tests = blk: {
        const mod = b.createModule(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "obzc", .module = obzc },
            },
        });

        mod.linkFramework("Foundation", .{ .needed = true });

        const tests = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(tests).step);
        break :blk mod;
    };

    _ = obzc_tests;
}
