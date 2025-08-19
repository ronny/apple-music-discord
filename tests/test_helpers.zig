const std = @import("std");

// Test helper functions and shared test utilities

pub const Config = struct {
    polling_interval_ms: u32 = 500,
};

pub const PlayerState = enum(c_int) {
    stopped = 0,
    playing = 1,
    paused = 2,
    fast_forwarding = 3,
    rewinding = 4,

    pub fn toString(self: PlayerState) []const u8 {
        return switch (self) {
            .playing => "Playing",
            .paused => "Paused",
            .fast_forwarding => "Fast Forwarding",
            .rewinding => "Rewinding",
            .stopped => "Stopped",
        };
    }
};

pub fn parseInterval(input: []const u8) !u32 {
    return std.fmt.parseInt(u32, input, 10);
}

pub fn validateInterval(interval: u32) u32 {
    if (interval < 100) {
        return 100;
    }
    return interval;
}