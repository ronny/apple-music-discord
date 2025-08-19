const std = @import("std");
const print = std.debug.print;
const musicScriptingBridge = @cImport({
    @cInclude("MusicScriptingBridge.h");
});

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
                print("Apple Music -> Discord Rich Presence Monitor\n\n", .{});
                print("Usage: {s} [options]\n\n", .{args[0]});
                print("Options:\n", .{});
                print("  --interval, -i <ms>  Polling interval in milliseconds (default: 500)\n", .{});
                print("  --help, -h           Show this help message\n", .{});
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const config = Config.parseArgs(allocator) catch |err| {
        print("Error parsing arguments: {}\n", .{err});
        std.process.exit(1);
    };

    print("🎧 Apple Music -> Discord Rich Presence Monitor\n", .{});
    print("Press Ctrl+C to exit. Change tracks to test detection.\n", .{});
    print("Polling interval: {}ms\n\n", .{config.polling_interval_ms});

    var lastTitle: ?[]const u8 = null;

    while (true) {
        // Check if Music app is running
        if (musicScriptingBridge.isMusicAppRunning() == 0) {
            print("⏸️  Apple Music is not running\n", .{});
            std.time.sleep(2 * std.time.ns_per_s); // Wait 2 seconds
            continue;
        }

        // Get current track info
        var track = musicScriptingBridge.getCurrentTrackInfo();
        defer musicScriptingBridge.freeTrackInfo(&track);

        if (track.isValid == 0) {
            if (lastTitle != null) {
                print("⏹️  No track loaded\n", .{});
                if (lastTitle) |title| allocator.free(title);
                lastTitle = null;
            }
            std.time.sleep(1 * std.time.ns_per_s);
            continue;
        }

        // Check if track changed
        var currentTitle: ?[]const u8 = null;
        if (track.title) |title| {
            const len = std.mem.len(title);
            currentTitle = allocator.dupe(u8, title[0..len]) catch null;
        }

        const trackChanged = blk: {
            if (lastTitle == null and currentTitle != null) break :blk true;
            if (lastTitle != null and currentTitle == null) break :blk true;
            if (lastTitle) |last| {
                if (currentTitle) |current| {
                    break :blk !std.mem.eql(u8, last, current);
                }
                break :blk true;
            }
            break :blk false;
        };

        if (trackChanged) {
            if (lastTitle) |title| allocator.free(title);
            lastTitle = currentTitle;
            print("🔄 Track changed: ", .{});
            printTrackInfo();
        }

        std.time.sleep(config.polling_interval_ms * std.time.ns_per_ms);
    }
}
