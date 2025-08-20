const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get Discord app ID from environment variable at compile time
    const discord_app_id_str = std.posix.getenv("DISCORD_APP_ID") orelse {
        std.debug.print("❌ ERROR: DISCORD_APP_ID environment variable must be set at compile time\n", .{});
        std.debug.print("🔍 Set it like: DISCORD_APP_ID=1234567890123456789 zig build\n", .{});
        std.posix.exit(1);
    };
    const discord_app_id = std.fmt.parseInt(i64, discord_app_id_str, 10) catch {
        std.debug.print("❌ ERROR: DISCORD_APP_ID must be a valid integer, got: {s}\n", .{discord_app_id_str});
        std.posix.exit(1);
    };

    // Discord Social SDK path configuration
    const discord_social_sdk_path = b.option([]const u8, "discord-social-sdk", "Path to Discord Social SDK directory") orelse
        std.posix.getenv("DISCORD_SOCIAL_SDK_PATH") orelse
        b.pathJoin(&.{ std.posix.getenv("HOME") orelse ".", "src", "discord_social_sdk" });

    // Generate version information
    const gen_version = b.addWriteFiles();
    const build_mode_str = @tagName(optimize);
    const debug_prefix = if (optimize == .Debug) "debug-" else "";
    const version_file = gen_version.add("version.zig", b.fmt(
        \\// Generated at build time
        \\const std = @import("std");
        \\
        \\// Version format: [debug-]YYYYMMDD-shorthash
        \\pub fn getVersion(allocator: std.mem.Allocator) ![]const u8 {{
        \\    // Get short commit hash
        \\    const hash_result = std.process.Child.run(.{{
        \\        .allocator = allocator,
        \\        .argv = &.{{ "git", "rev-parse", "--short", "HEAD" }},
        \\    }}) catch |err| {{
        \\        std.debug.print("Warning: Could not get commit hash: {{}}\n", .{{err}});
        \\        return allocator.dupe(u8, "{s}unknown-unknown");
        \\    }};
        \\    defer allocator.free(hash_result.stdout);
        \\    defer allocator.free(hash_result.stderr);
        \\
        \\    if (hash_result.term != .Exited or hash_result.term.Exited != 0) {{
        \\        return allocator.dupe(u8, "{s}unknown-unknown");
        \\    }}
        \\
        \\    const hash = std.mem.trim(u8, hash_result.stdout, " \t\n\r");
        \\
        \\    // Get commit date in UTC using ISO format
        \\    const date_result = std.process.Child.run(.{{
        \\        .allocator = allocator,
        \\        .argv = &.{{ "git", "show", "-s", "--format=%cd", "--date=format:%Y%m%d", "HEAD" }},
        \\    }}) catch |err| {{
        \\        std.debug.print("Warning: Could not get commit date: {{}}\n", .{{err}});
        \\        return std.fmt.allocPrint(allocator, "{s}unknown-{{s}}", .{{hash}});
        \\    }};
        \\    defer allocator.free(date_result.stdout);
        \\    defer allocator.free(date_result.stderr);
        \\
        \\    if (date_result.term != .Exited or date_result.term.Exited != 0) {{
        \\        return std.fmt.allocPrint(allocator, "{s}unknown-{{s}}", .{{hash}});
        \\    }}
        \\
        \\    const date = std.mem.trim(u8, date_result.stdout, " \t\n\r");
        \\    return std.fmt.allocPrint(allocator, "{s}{{s}}-{{s}}", .{{date, hash}});
        \\}}
        \\
        \\pub const build_mode = "{s}";
        \\
    , .{ debug_prefix, debug_prefix, debug_prefix, debug_prefix, debug_prefix, build_mode_str }));

    const exe = b.addExecutable(.{
        .name = "music-discord-presence",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the Objective-C bridge source
    exe.addCSourceFile(.{
        .file = b.path("MusicScriptingBridge.m"),
        .flags = &.{"-fobjc-arc"}, // Enable ARC for Objective-C
    });

    exe.root_module.addAnonymousImport("version", .{ .root_source_file = version_file });

    // Add Discord app ID as a build option
    const options = b.addOptions();
    options.addOption(i64, "discord_app_id", discord_app_id);
    exe.root_module.addOptions("config", options);

    // Add the header include path
    exe.addIncludePath(b.path("."));

    // Discord Social SDK integration (required)
    const discord_include_path = b.pathJoin(&.{ discord_social_sdk_path, "include" });

    // Check if Discord Social SDK exists - fail build if not found
    const discord_header = b.pathJoin(&.{ discord_include_path, "cdiscord.h" });
    std.fs.cwd().access(discord_header, .{}) catch {
        std.debug.print("❌ ERROR: Discord Social SDK not found at: {s}\n", .{discord_social_sdk_path});
        std.debug.print("📥 Download from: https://discord.com/developers/applications/APP_ID/social-sdk/downloads (replace APP_ID with your actual app ID)\n", .{});
        std.debug.print("📁 Extract to: {s}\n", .{discord_social_sdk_path});
        std.debug.print("⚙️  Or specify custom path: zig build -Ddiscord-social-sdk=/path/to/discord_social_sdk\n", .{});
        std.posix.exit(1);
    };

    // Detect the correct library path (release vs debug, platform-specific)
    const discord_lib_path = blk: {
        const build_mode = if (optimize == .Debug) "debug" else "release";
        const lib_base = b.pathJoin(&.{ discord_social_sdk_path, "lib", build_mode });

        // Check for the dylib in the build mode directory
        const dylib_path = b.pathJoin(&.{ lib_base, "libdiscord_partner_sdk.dylib" });
        std.fs.cwd().access(dylib_path, .{}) catch {
            // Fall back to the base lib directory
            const fallback_lib_path = b.pathJoin(&.{ discord_social_sdk_path, "lib" });
            const fallback_dylib = b.pathJoin(&.{ fallback_lib_path, "libdiscord_partner_sdk.dylib" });
            std.fs.cwd().access(fallback_dylib, .{}) catch {
                std.debug.print("❌ ERROR: Discord Social SDK library not found\n", .{});
                std.debug.print("🔍 Searched for libdiscord_partner_sdk.dylib in:\n", .{});
                std.debug.print("   - {s}\n", .{dylib_path});
                std.debug.print("   - {s}\n", .{fallback_dylib});
                std.debug.print("📋 Available files in {s}:\n", .{lib_base});

                // Try to list available files for debugging
                if (std.fs.cwd().openDir(lib_base, .{ .iterate = true })) |dir| {
                    var walker = dir.iterate();
                    while (walker.next() catch null) |entry| {
                        std.debug.print("   - {s}\n", .{entry.name});
                    }
                } else |_| {
                    std.debug.print("   (could not list directory)\n", .{});
                }

                std.posix.exit(1);
            };
            break :blk fallback_lib_path;
        };
        break :blk lib_base;
    };

    exe.addIncludePath(.{ .cwd_relative = discord_include_path });
    exe.addLibraryPath(.{ .cwd_relative = discord_lib_path });
    exe.linkSystemLibrary("discord_partner_sdk");

    std.debug.print("✅ Discord Social SDK found at: {s}\n", .{discord_social_sdk_path});
    std.debug.print("📚 Using library path: {s}\n", .{discord_lib_path});

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

    const memory_test = b.addTest(.{
        .root_source_file = b.path("tests/memory_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const config_test_run = b.addRunArtifact(config_test);
    const music_bridge_test_run = b.addRunArtifact(music_bridge_test);
    const integration_test_run = b.addRunArtifact(integration_test);
    const memory_test_run = b.addRunArtifact(memory_test);

    const test_config_step = b.step("test-config", "Run config tests");
    test_config_step.dependOn(&config_test_run.step);

    const test_music_step = b.step("test-music", "Run music bridge tests");
    test_music_step.dependOn(&music_bridge_test_run.step);

    const test_integration_step = b.step("test-integration", "Run integration tests");
    test_integration_step.dependOn(&integration_test_run.step);

    const test_memory_step = b.step("test-memory", "Run memory leak tests");
    test_memory_step.dependOn(&memory_test_run.step);

    const test_all_step = b.step("test-all", "Run all tests");
    test_all_step.dependOn(&config_test_run.step);
    test_all_step.dependOn(&music_bridge_test_run.step);
    test_all_step.dependOn(&integration_test_run.step);
    test_all_step.dependOn(&memory_test_run.step);

    // Music.h generation step (requires full Xcode installation)
    const music_header_cmd = b.addSystemCommand(&.{ "sh", "-c", "sdef /System/Applications/Music.app | sdp -fh --basename Music" });
    music_header_cmd.setCwd(b.path("."));

    const music_header_step = b.step("Music.h", "Generate Music.h header from Apple Music.app (requires Xcode)");
    music_header_step.dependOn(&music_header_cmd.step);
}
