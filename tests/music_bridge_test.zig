const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

// Import C functions
const c = @cImport({
    @cInclude("MusicScriptingBridge.h");
});

test "MusicPlayerState enum values" {
    try expectEqual(@as(c_int, 0), c.MusicPlayerStateStopped);
    try expectEqual(@as(c_int, 1), c.MusicPlayerStatePlaying);
    try expectEqual(@as(c_int, 2), c.MusicPlayerStatePaused);
    try expectEqual(@as(c_int, 3), c.MusicPlayerStateFastForwarding);
    try expectEqual(@as(c_int, 4), c.MusicPlayerStateRewinding);
}

test "DetailedTrackInfo structure initialization" {
    const track_info = c.DetailedTrackInfo{
        .isValid = 0,
        .title = null,
        .artist = null,
        .album = null,
        .albumArtist = null,
        .composer = null,
        .genre = null,
        .year = 0,
        .trackNumber = 0,
        .trackCount = 0,
        .discNumber = 0,
        .discCount = 0,
        .duration = 0.0,
        .playedCount = 0,
        .rating = 0,
        .playedDate = 0.0,
        .isPlaying = 0,
        .isPaused = 0,
    };
    
    try expectEqual(@as(c_int, 0), track_info.isValid);
    try expectEqual(@as(?[*:0]u8, null), track_info.title);
    try expectEqual(@as(?[*:0]u8, null), track_info.artist);
    try expectEqual(@as(f64, 0.0), track_info.duration);
}

test "Music app running check - basic call" {
    // This test verifies the function can be called without crashing
    // The actual result depends on whether Music.app is running
    const result = c.isMusicAppRunning();
    try expect(result == 0 or result == 1); // Should return 0 or 1
}

test "Player state retrieval - basic call" {
    // This test verifies the function can be called without crashing
    const state = c.getPlayerState();
    
    // State should be one of the valid enum values
    try expect(state >= c.MusicPlayerStateStopped and state <= c.MusicPlayerStateRewinding);
}

test "Player position retrieval - basic call" {
    // This test verifies the function can be called without crashing
    const position = c.getPlayerPosition();
    
    // Position should be a valid floating point number (>= 0)
    try expect(position >= 0.0);
    try expect(std.math.isFinite(position));
}

test "Track info memory management" {
    // Test that getCurrentTrackInfo can be called and freed safely
    var track_info = c.getCurrentTrackInfo();
    defer c.freeTrackInfo(&track_info);
    
    // Verify that isValid is either 0 or 1
    try expect(track_info.isValid == 0 or track_info.isValid == 1);
    
    // If track is valid, some basic sanity checks
    if (track_info.isValid == 1) {
        // Duration should be non-negative if set
        try expect(track_info.duration >= 0.0);
        
        // Year should be reasonable if set
        if (track_info.year > 0) {
            try expect(track_info.year >= 1900 and track_info.year <= 2030);
        }
        
        // Track numbers should be non-negative
        try expect(track_info.trackNumber >= 0);
        try expect(track_info.trackCount >= 0);
        try expect(track_info.discNumber >= 0);
        try expect(track_info.discCount >= 0);
        try expect(track_info.playedCount >= 0);
        
        // Rating should be in valid range (0-100)
        try expect(track_info.rating >= 0 and track_info.rating <= 100);
    }
}

test "Player state consistency" {
    // Test that player state and track info are consistent
    const state = c.getPlayerState();
    var track_info = c.getCurrentTrackInfo();
    defer c.freeTrackInfo(&track_info);
    
    if (track_info.isValid == 1) {
        // If we have valid track info, check consistency
        if (state == c.MusicPlayerStatePlaying) {
            try expect(track_info.isPlaying == 1);
            try expect(track_info.isPaused == 0);
        } else if (state == c.MusicPlayerStatePaused) {
            try expect(track_info.isPlaying == 0);
            try expect(track_info.isPaused == 1);
        } else {
            // Stopped, fast forwarding, or rewinding
            try expect(track_info.isPlaying == 0);
        }
    }
}

test "String handling safety" {
    var track_info = c.getCurrentTrackInfo();
    defer c.freeTrackInfo(&track_info);
    
    if (track_info.isValid == 1) {
        // Test that string pointers are either null or valid
        if (track_info.title) |title| {
            const len = std.mem.len(title);
            try expect(len > 0); // Non-empty string
            try expect(len < 1000); // Reasonable length
        }
        
        if (track_info.artist) |artist| {
            const len = std.mem.len(artist);
            try expect(len > 0);
            try expect(len < 1000);
        }
        
        if (track_info.album) |album| {
            const len = std.mem.len(album);
            try expect(len > 0);
            try expect(len < 1000);
        }
    }
}

test "Multiple calls consistency" {
    // Test that multiple calls return consistent results
    const state1 = c.getPlayerState();
    std.time.sleep(10 * std.time.ns_per_ms); // Wait 10ms
    const state2 = c.getPlayerState();
    
    // States should be the same or reasonable transitions
    if (state1 == state2) {
        // Same state is always valid
        try expect(true);
    } else {
        // Valid state transitions
        const valid_transition = switch (state1) {
            c.MusicPlayerStatePlaying => state2 == c.MusicPlayerStatePaused or 
                                       state2 == c.MusicPlayerStateStopped or
                                       state2 == c.MusicPlayerStateFastForwarding or
                                       state2 == c.MusicPlayerStateRewinding,
            c.MusicPlayerStatePaused => state2 == c.MusicPlayerStatePlaying or 
                                      state2 == c.MusicPlayerStateStopped,
            c.MusicPlayerStateStopped => state2 == c.MusicPlayerStatePlaying,
            else => true, // Other transitions are possible
        };
        try expect(valid_transition);
    }
}