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

    // Add test executable
    const test_exe = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the same C source and frameworks for tests
    test_exe.addCSourceFile(.{
        .file = b.path("MusicScriptingBridge.m"),
        .flags = &.{"-fobjc-arc"},
    });
    test_exe.addIncludePath(b.path("."));
    test_exe.linkFramework("Foundation");
    test_exe.linkFramework("ScriptingBridge");
    test_exe.linkFramework("Cocoa");
    test_exe.linkLibC();

    const test_run = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run.step);

    // Add individual test files
    const config_test = b.addTest(.{
        .root_source_file = b.path("tests/config_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const music_bridge_test = b.addTest(.{
        .root_source_file = b.path("tests/music_bridge_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    music_bridge_test.addCSourceFile(.{
        .file = b.path("MusicScriptingBridge.m"),
        .flags = &.{"-fobjc-arc"},
    });
    music_bridge_test.addIncludePath(b.path("."));
    music_bridge_test.linkFramework("Foundation");
    music_bridge_test.linkFramework("ScriptingBridge");
    music_bridge_test.linkFramework("Cocoa");
    music_bridge_test.linkLibC();

    const integration_test = b.addTest(.{
        .root_source_file = b.path("tests/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_test.addCSourceFile(.{
        .file = b.path("MusicScriptingBridge.m"),
        .flags = &.{"-fobjc-arc"},
    });
    integration_test.addIncludePath(b.path("."));
    integration_test.linkFramework("Foundation");
    integration_test.linkFramework("ScriptingBridge");
    integration_test.linkFramework("Cocoa");
    integration_test.linkLibC();

    const config_test_run = b.addRunArtifact(config_test);
    const music_bridge_test_run = b.addRunArtifact(music_bridge_test);
    const integration_test_run = b.addRunArtifact(integration_test);

    const test_config_step = b.step("test-config", "Run config tests");
    test_config_step.dependOn(&config_test_run.step);

    const test_music_step = b.step("test-music", "Run music bridge tests");
    test_music_step.dependOn(&music_bridge_test_run.step);

    const test_integration_step = b.step("test-integration", "Run integration tests");
    test_integration_step.dependOn(&integration_test_run.step);

    const test_all_step = b.step("test-all", "Run all tests");
    test_all_step.dependOn(&config_test_run.step);
    test_all_step.dependOn(&music_bridge_test_run.step);
    test_all_step.dependOn(&integration_test_run.step);
}