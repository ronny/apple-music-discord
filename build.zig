const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "apple-music-discord-presence",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the Objective-C bridge source
    exe.addCSourceFile(.{
        .file = b.path("MusicScriptingBridge.m"),
        .flags = &.{"-fobjc-arc"}, // Enable ARC for Objective-C
    });

    // Add the header include path
    exe.addIncludePath(b.path("."));

    // exe.addIncludePath(b.path("./discord/include"));
    // exe.addLibraryPath(b.path("./discord/lib"));
    // exe.linkSystemLibrary("discord_partner_sdk");

    // Link required macOS frameworks
    exe.linkFramework("Foundation");
    exe.linkFramework("ScriptingBridge");
    exe.linkFramework("Cocoa");
    exe.linkLibC();

    b.installArtifact(exe);

    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}