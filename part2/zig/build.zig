const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});


    const generator_mod  = b.createModule(.{
        .root_source_file = b.path("src/listing_0066_haversine_generator_main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const generator_exe = b.addExecutable(.{
        .name = "generator",
        .root_module = generator_mod,
    });

    b.installArtifact(generator_exe);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "part2",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);
}
