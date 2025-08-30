const std = @import("std");
const print = std.debug.print;
const musicScriptingBridge = @cImport({
    @cInclude("MusicScriptingBridge.h");
});
const Discord = @import("discord_bridge.zig").Discord;
const version = @import("version.zig");

// Global state for graceful shutdown
var shutdown_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
var discord_client: ?*Discord = null;
var cleanup_allocator: ?std.mem.Allocator = null;
var cleanup_last_title: ?*?[]const u8 = null;
var cleanup_last_state: ?*?[]const u8 = null;

// Signal handler for graceful shutdown
fn handleShutdownSignal(sig: c_int) callconv(.c) void {
    const signal_name = switch (sig) {
        std.posix.SIG.INT => "SIGINT",
        std.posix.SIG.TERM => "SIGTERM",
        else => "UNKNOWN",
    };

    print("\n🛑 Received {s}, shutting down gracefully...\n", .{signal_name});
    shutdown_requested.store(true, .seq_cst);
}

// Cleanup function called during shutdown
fn performGracefulShutdown() void {
    print("🧹 Cleaning up resources...\n", .{});

    // Clear Discord activity
    if (discord_client) |client| {
        client.clearActivity() catch |err| {
            print("Warning: Failed to clear Discord activity: {}\n", .{err});
        };
        print("✓ Discord activity cleared\n", .{});
    }

    // Clear ScriptingBridge cache
    musicScriptingBridge.clearTrackCache();
    print("✓ ScriptingBridge cache cleared\n", .{});

    // Clean up allocated memory
    if (cleanup_allocator) |allocator| {
        if (cleanup_last_title) |title_ptr| {
            if (title_ptr.*) |title| {
                allocator.free(title);
                title_ptr.* = null;
            }
        }
        if (cleanup_last_state) |state_ptr| {
            if (state_ptr.*) |state| {
                allocator.free(state);
                state_ptr.* = null;
            }
        }
        print("✓ Memory cleaned up\n", .{});
    }

    print("👋 Graceful shutdown complete\n", .{});
}

const Config = struct {
    polling_interval_ms: u32 = 500,

    fn parseArgs(allocator: std.mem.Allocator) !Config {
        var config = Config{};

        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                const app_version = version.getVersion(allocator) catch "unknown";
                defer allocator.free(app_version);

                print("Apple Music.app -> Discord Rich Presence Monitor version {s}\n\n", .{app_version});
                print("Usage: {s} [options]\n\n", .{args[0]});
                print("Options:\n", .{});
                print("  --interval, -i <ms>  Polling interval in milliseconds (default: 500)\n", .{});
                print("  --version, -v        Show version information\n", .{});
                print("  --help, -h           Show this help message\n", .{});
                std.process.exit(0);
            } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
                const app_version = version.getVersion(allocator) catch "unknown";
                defer allocator.free(app_version);

                print("music-discord-presence version {s}\n", .{app_version});
                print("Build mode: {s}\n", .{version.build_mode});
                std.process.exit(0);
            } else if (std.mem.eql(u8, arg, "--interval") or std.mem.eql(u8, arg, "-i")) {
                if (i + 1 >= args.len) {
                    print("Error: --interval requires a value\n", .{});
                    std.process.exit(1);
                }
                i += 1;
                config.polling_interval_ms = std.fmt.parseInt(u32, args[i], 10) catch |err| {
                    print("Error: Invalid interval value '{s}': {}\n", .{ args[i], err });
                    std.process.exit(1);
                };
                if (config.polling_interval_ms < 100) {
                    print("Warning: Polling interval too low ({}ms), setting to 100ms minimum\n", .{config.polling_interval_ms});
                    config.polling_interval_ms = 100;
                }
            } else {
                print("Error: Unknown argument '{s}'\n", .{arg});
                print("Use --help for usage information\n", .{});
                std.process.exit(1);
            }
        }

        return config;
    }
};

const PlayerState = enum(c_int) {
    stopped = 0,
    playing = 1,
    paused = 2,
    fast_forwarding = 3,
    rewinding = 4,

    fn toString(self: PlayerState) []const u8 {
        return switch (self) {
            .playing => "Playing",
            .paused => "Paused",
            .fast_forwarding => "Fast Forwarding",
            .rewinding => "Rewinding",
            .stopped => "Stopped",
        };
    }
};

fn formatDuration(seconds: f64) void {
    const minutes = @as(u32, @intFromFloat(seconds / 60.0));
    const secs = @as(u32, @intFromFloat(@mod(seconds, 60.0)));
    print("{d}:{d:0>2} ({d:.2} seconds)", .{ minutes, secs, seconds });
}

fn formatTime(timestamp: f64) void {
    if (timestamp <= 0) return;

    const time_t = @as(i64, @intFromFloat(timestamp));
    const datetime = std.time.epoch.EpochSeconds{ .secs = @intCast(time_t) };
    const day_seconds = datetime.getDaySeconds();
    const epoch_day = datetime.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    print("{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        year_day.year,
        @intFromEnum(month_day.month),
        month_day.day_index + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
    });
}

fn printOptionalString(label: []const u8, value: ?[*:0]u8) void {
    if (value) |str| {
        const len = std.mem.len(str);
        print("{s}: {s}\n", .{ label, str[0..len] });
    }
}

fn printTrackInfo() void {
    // Get current track info
    var track = musicScriptingBridge.getCurrentTrackInfo();
    defer musicScriptingBridge.freeTrackInfo(&track);

    if (track.isValid == 0) {
        print("No track currently loaded\n", .{});
        return;
    }

    print("🎵 ", .{});

    // Basic track information
    if (track.title) |title| {
        const len = std.mem.len(title);
        print("{s}", .{title[0..len]});
    }

    if (track.artist) |artist| {
        const len = std.mem.len(artist);
        print(" - {s}", .{artist[0..len]});
    }

    // Player state
    const state: PlayerState = @enumFromInt(musicScriptingBridge.getPlayerState());
    print(" [{s}]", .{state.toString()});

    // Current position
    const position = musicScriptingBridge.getPlayerPosition();
    if (position > 0 and track.duration > 0) {
        const percentage = (position / track.duration) * 100.0;
        print(" ({d:.1}%)", .{percentage});
    }

    print("\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = true,
        .retain_metadata = true,
    }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            print("⚠️  Memory leaks detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    const config = Config.parseArgs(allocator) catch |err| {
        print("Error parsing arguments: {}\n", .{err});
        std.process.exit(1);
    };

    // Get Discord app ID from build configuration
    const build_config = @import("config");
    const discord_app_id: i64 = build_config.discord_app_id;

    const app_version = version.getVersion(allocator) catch "unknown";
    defer allocator.free(app_version);

    print("🎧 Apple Music -> Discord Rich Presence Monitor version {s}\n", .{app_version});
    print("Press Ctrl+C to exit. Change tracks to test detection.\n", .{});
    print("Polling interval: {}ms\n", .{config.polling_interval_ms});
    print("Discord app ID: {}\n\n", .{discord_app_id});

    // Register signal handlers for graceful shutdown
    const sigint_action = std.posix.Sigaction{
        .handler = .{ .handler = handleShutdownSignal },
        .mask = std.mem.zeroes(std.posix.sigset_t),
        .flags = 0,
    };
    const sigterm_action = std.posix.Sigaction{
        .handler = .{ .handler = handleShutdownSignal },
        .mask = std.mem.zeroes(std.posix.sigset_t),
        .flags = 0,
    };

    std.posix.sigaction(std.posix.SIG.INT, &sigint_action, null);
    std.posix.sigaction(std.posix.SIG.TERM, &sigterm_action, null);

    // Initialize Discord client
    var discord = Discord.init(allocator, discord_app_id) catch |err| {
        print("❌ ERROR: Failed to initialize Discord client: {}\n", .{err});
        print("🔍 Make sure Discord.app is running\n", .{});
        print("🔍 Make sure the Discord Social SDK application ID ({}) is correct\n", .{discord_app_id});
        std.process.exit(1);
    };
    defer discord.deinit();

    var lastTitle: ?[]const u8 = null;
    var lastState: ?[]const u8 = null;

    // Set up global cleanup state for signal handlers
    discord_client = &discord;
    cleanup_allocator = allocator;
    cleanup_last_title = &lastTitle;
    cleanup_last_state = &lastState;

    while (!shutdown_requested.load(.seq_cst)) {
        // Check if Music app is running
        if (musicScriptingBridge.isMusicAppRunning() == 0) {
            if (lastTitle != null) {
                print("⏸️  Apple Music is not running\n", .{});
                discord.clearActivity() catch {};
                if (lastTitle) |title| allocator.free(title);
                lastTitle = null;
                if (lastState) |old_state| allocator.free(old_state);
                lastState = null;
            }
            discord.runCallbacks();
            std.Thread.sleep(2 * std.time.ns_per_s); // Wait 2 seconds
            continue;
        }

        // Get current track info
        var track = musicScriptingBridge.getCurrentTrackInfo();
        defer musicScriptingBridge.freeTrackInfo(&track);

        if (track.isValid == 0) {
            if (lastTitle != null) {
                print("⏹️  No track loaded\n", .{});
                discord.clearActivity() catch {};
                if (lastTitle) |title| allocator.free(title);
                lastTitle = null;
                if (lastState) |old_state| allocator.free(old_state);
                lastState = null;
            }
            std.Thread.sleep(1 * std.time.ns_per_s);
            continue;
        }

        // Get current track title and player state (without allocating yet)
        const currentTitleStr: ?[]const u8 = if (track.title) |title| blk: {
            const len = std.mem.len(title);
            break :blk title[0..len];
        } else null;

        const state: PlayerState = @enumFromInt(musicScriptingBridge.getPlayerState());
        const currentStateStr = state.toString();

        const trackChanged = blk: {
            if (lastTitle == null and currentTitleStr != null) break :blk true;
            if (lastTitle != null and currentTitleStr == null) break :blk true;
            if (lastTitle) |last| {
                if (currentTitleStr) |current| {
                    break :blk !std.mem.eql(u8, last, current);
                }
                break :blk true;
            }
            break :blk false;
        };

        const stateChanged = blk: {
            if (lastState == null and currentStateStr.len > 0) break :blk true;
            if (lastState) |last| {
                break :blk !std.mem.eql(u8, last, currentStateStr);
            }
            break :blk true; // First time, no lastState
        };

        if (trackChanged or stateChanged) {
            if (trackChanged) {
                if (lastTitle) |title| allocator.free(title);
                lastTitle = if (currentTitleStr) |title| allocator.dupe(u8, title) catch null else null;
                print("🔄 Track changed: ", .{});
                printTrackInfo();

                // Debug: Print IDs for URL construction
                if (track.persistentID) |pid| {
                    const pid_len = std.mem.len(pid);
                    print("🔍 Persistent ID: {s}\n", .{pid[0..pid_len]});
                }
                print("🔍 Database ID: {}\n", .{track.databaseID});
            } else {
                // Only state changed
                print("🔄 State changed: ", .{});
                printTrackInfo();
            }

            if (lastState) |old_state| allocator.free(old_state);
            lastState = allocator.dupe(u8, currentStateStr) catch null;

            // Update Discord activity (or clear if stopped/paused)
            if (state == .stopped) {
                print("⏹️  Player stopped - clearing Discord activity\n", .{});
                discord.clearActivity() catch |err| {
                    print("Warning: Failed to clear Discord activity: {}\n", .{err});
                };
            } else if (state == .paused) {
                print("⏸️  Player paused - clearing Discord activity\n", .{});
                discord.clearActivity() catch |err| {
                    print("Warning: Failed to clear Discord activity: {}\n", .{err});
                };
            } else {
                const artist_str = if (track.artist) |a| blk: {
                    const len = std.mem.len(a);
                    break :blk a[0..len];
                } else null;

                // Get current player position for accurate timestamps
                const player_position = musicScriptingBridge.getPlayerPosition();

                discord.updateActivity(currentTitleStr, artist_str, currentStateStr, player_position, track.duration) catch |err| {
                    print("Warning: Failed to update Discord activity: {}\n", .{err});
                };
            }
        }

        // Run Discord callbacks to process events
        discord.runCallbacks();

        std.Thread.sleep(config.polling_interval_ms * std.time.ns_per_ms);
    }

    // Perform graceful shutdown when exiting main loop
    performGracefulShutdown();
    std.process.exit(0);
}
