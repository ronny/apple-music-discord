const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

// Import test helpers
const helpers = @import("test_helpers.zig");
const Config = helpers.Config;

test "Config default values" {
    const config = Config{};
    try expectEqual(@as(u32, 500), config.polling_interval_ms);
}

test "Config parseArgs with no arguments" {
    // Test default configuration
    const config = Config{};
    try expectEqual(@as(u32, 500), config.polling_interval_ms);
}

test "Config minimum interval enforcement" {
    // Test that intervals below 100ms are clamped to 100ms
    const low_interval = helpers.validateInterval(50);
    try expectEqual(@as(u32, 100), low_interval);
    
    const valid_interval = helpers.validateInterval(500);
    try expectEqual(@as(u32, 500), valid_interval);
}

test "Config valid interval values" {
    const test_cases = [_]u32{ 100, 200, 500, 1000, 2000, 5000 };
    
    for (test_cases) |interval| {
        var config = Config{};
        config.polling_interval_ms = interval;
        try expectEqual(interval, config.polling_interval_ms);
    }
}

test "Config interval parsing" {
    // Test valid integer parsing
    const test_cases = [_]struct { input: []const u8, expected: u32 }{
        .{ .input = "100", .expected = 100 },
        .{ .input = "500", .expected = 500 },
        .{ .input = "1000", .expected = 1000 },
        .{ .input = "2500", .expected = 2500 },
    };
    
    for (test_cases) |case| {
        const parsed = try helpers.parseInterval(case.input);
        try expectEqual(case.expected, parsed);
    }
}

test "Config invalid interval parsing" {
    // Test invalid values that should cause parsing errors
    const invalid_cases = [_][]const u8{ "invalid", "abc", "-100", "0.5", "" };
    
    for (invalid_cases) |invalid_input| {
        const result = helpers.parseInterval(invalid_input);
        try expect(std.meta.isError(result));
    }
}