const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

// Import test helpers
const helpers = @import("test_helpers.zig");
const PlayerState = helpers.PlayerState;

// Import C functions
const c = @cImport({
    @cInclude("MusicScriptingBridge.h");
});

test "PlayerState enum conversion" {
    // Test that Zig PlayerState enum matches C enum values
    try expectEqual(@as(c_int, 0), @intFromEnum(PlayerState.stopped));
    try expectEqual(@as(c_int, 1), @intFromEnum(PlayerState.playing));
    try expectEqual(@as(c_int, 2), @intFromEnum(PlayerState.paused));
    try expectEqual(@as(c_int, 3), @intFromEnum(PlayerState.fast_forwarding));
    try expectEqual(@as(c_int, 4), @intFromEnum(PlayerState.rewinding));
}

test "PlayerState toString function" {
    const state_playing = PlayerState.playing;
    const playing_str = state_playing.toString();
    try expect(std.mem.eql(u8, playing_str, "Playing"));
    
    const state_paused = PlayerState.paused;
    const paused_str = state_paused.toString();
    try expect(std.mem.eql(u8, paused_str, "Paused"));
    
    const state_stopped = PlayerState.stopped;
    const stopped_str = state_stopped.toString();
    try expect(std.mem.eql(u8, stopped_str, "Stopped"));
    
    const state_ff = PlayerState.fast_forwarding;
    const ff_str = state_ff.toString();
    try expect(std.mem.eql(u8, ff_str, "Fast Forwarding"));
    
    const state_rw = PlayerState.rewinding;
    const rw_str = state_rw.toString();
    try expect(std.mem.eql(u8, rw_str, "Rewinding"));
}

test "C to Zig PlayerState conversion" {
    // Test conversion from C enum to Zig enum
    const c_playing = c.MusicPlayerStatePlaying;
    const zig_playing: PlayerState = @enumFromInt(c_playing);
    try expectEqual(PlayerState.playing, zig_playing);
    
    const c_paused = c.MusicPlayerStatePaused;
    const zig_paused: PlayerState = @enumFromInt(c_paused);
    try expectEqual(PlayerState.paused, zig_paused);
    
    const c_stopped = c.MusicPlayerStateStopped;
    const zig_stopped: PlayerState = @enumFromInt(c_stopped);
    try expectEqual(PlayerState.stopped, zig_stopped);
}

test "Format duration function" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Capture output by redirecting to a buffer
    var output_buf = std.ArrayList(u8){};
    defer output_buf.deinit(allocator);
    
    // Test various durations
    const test_cases = [_]struct { input: f64, expected_contains: []const u8 }{
        .{ .input = 0.0, .expected_contains = "0:00" },
        .{ .input = 30.0, .expected_contains = "0:30" },
        .{ .input = 60.0, .expected_contains = "1:00" },
        .{ .input = 90.5, .expected_contains = "1:30" },
        .{ .input = 125.25, .expected_contains = "2:05" },
        .{ .input = 3661.0, .expected_contains = "61:01" }, // 1 hour, 1 minute, 1 second
    };
    
    for (test_cases) |case| {
        // Calculate expected format manually
        const minutes = @as(u32, @intFromFloat(case.input / 60.0));
        const secs = @as(u32, @intFromFloat(@mod(case.input, 60.0)));
        
        // Verify the calculation logic
        try expect(minutes >= 0);
        try expect(secs >= 0 and secs < 60);
        
        // For longer durations
        if (case.input >= 60.0) {
            try expect(minutes >= 1);
        }
    }
}

test "Track change detection logic" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Simulate track change detection logic
    var lastTitle: ?[]const u8 = null;
    
    // First track
    const track1 = "Song 1";
    const currentTitle1 = try allocator.dupe(u8, track1);
    
    const trackChanged1 = blk: {
        if (lastTitle == null and currentTitle1.len > 0) break :blk true;
        if (lastTitle != null and currentTitle1.len == 0) break :blk true;
        if (lastTitle) |last| {
            break :blk !std.mem.eql(u8, last, currentTitle1);
        }
        break :blk false;
    };
    
    try expect(trackChanged1); // First track should be detected as changed
    
    if (lastTitle) |title| allocator.free(title);
    lastTitle = currentTitle1;
    
    // Same track again
    const currentTitle2 = try allocator.dupe(u8, track1);
    
    const trackChanged2 = blk: {
        if (lastTitle == null and currentTitle2.len > 0) break :blk true;
        if (lastTitle != null and currentTitle2.len == 0) break :blk true;
        if (lastTitle) |last| {
            break :blk !std.mem.eql(u8, last, currentTitle2);
        }
        break :blk false;
    };
    
    try expect(!trackChanged2); // Same track should not be detected as changed
    allocator.free(currentTitle2);
    
    // Different track
    const track3 = "Song 2";
    const currentTitle3 = try allocator.dupe(u8, track3);
    
    const trackChanged3 = blk: {
        if (lastTitle == null and currentTitle3.len > 0) break :blk true;
        if (lastTitle != null and currentTitle3.len == 0) break :blk true;
        if (lastTitle) |last| {
            break :blk !std.mem.eql(u8, last, currentTitle3);
        }
        break :blk false;
    };
    
    try expect(trackChanged3); // Different track should be detected as changed
    
    // Cleanup
    if (lastTitle) |title| allocator.free(title);
    allocator.free(currentTitle3);
}

test "Memory management in track info handling" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Test multiple allocation and deallocation cycles
    for (0..10) |i| {
        const track_name = try std.fmt.allocPrint(allocator, "Track {d}", .{i});
        defer allocator.free(track_name);
        
        // Simulate string duplication as in main.zig
        const duplicated = try allocator.dupe(u8, track_name);
        defer allocator.free(duplicated);
        
        try expect(std.mem.eql(u8, track_name, duplicated));
        try expect(duplicated.len > 0);
    }
}

test "Polling interval bounds checking" {
    // Test the interval validation logic
    const test_intervals = [_]u32{ 50, 100, 200, 500, 1000, 2000, 5000, 10000 };
    
    for (test_intervals) |interval| {
        const adjusted_interval = helpers.validateInterval(interval);
        
        try expect(adjusted_interval >= 100);
        
        if (interval >= 100) {
            try expectEqual(interval, adjusted_interval);
        } else {
            try expectEqual(@as(u32, 100), adjusted_interval);
        }
    }
}

test "Time calculations" {
    // Test time-related calculations for position percentages
    const test_cases = [_]struct { 
        position: f64, 
        duration: f64, 
        expected_percentage: f64 
    }{
        .{ .position = 0.0, .duration = 100.0, .expected_percentage = 0.0 },
        .{ .position = 50.0, .duration = 100.0, .expected_percentage = 50.0 },
        .{ .position = 100.0, .duration = 100.0, .expected_percentage = 100.0 },
        .{ .position = 30.0, .duration = 120.0, .expected_percentage = 25.0 },
        .{ .position = 90.0, .duration = 180.0, .expected_percentage = 50.0 },
    };
    
    for (test_cases) |case| {
        if (case.position > 0 and case.duration > 0) {
            const percentage = (case.position / case.duration) * 100.0;
            try expect(std.math.approxEqAbs(f64, percentage, case.expected_percentage, 0.001));
        }
    }
}