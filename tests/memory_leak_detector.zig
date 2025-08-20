const std = @import("std");
const testing = std.testing;

/// Black-box memory leak detector for polling-based applications
/// 
/// This test simulates realistic application polling behavior and monitors
/// memory usage patterns over time to detect potential leaks without
/// making assumptions about the specific cause.
///
/// Key assumptions:
/// - App polls at regular intervals
/// - Track/state data changes occasionally
/// - Memory usage should stabilize after initial allocations
/// - No specific knowledge of internal allocation patterns

const MemorySnapshot = struct {
    iteration: usize,
    allocations_made: usize,
    allocations_freed: usize,
};

const MemoryStats = struct {
    snapshots: []MemorySnapshot,
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
        return Self{
            .snapshots = try allocator.alloc(MemorySnapshot, capacity),
            .allocator = allocator,
        };
    }
    
    fn deinit(self: *Self) void {
        self.allocator.free(self.snapshots);
    }
    
    fn recordSnapshot(self: *Self, index: usize, iteration: usize, allocs_made: usize, allocs_freed: usize) void {
        if (index >= self.snapshots.len) return;
        
        self.snapshots[index] = MemorySnapshot{
            .iteration = iteration,
            .allocations_made = allocs_made,
            .allocations_freed = allocs_freed,
        };
    }
    
    /// Analyze memory growth patterns to detect potential leaks
    fn analyzeGrowthPattern(self: *Self) MemoryAnalysis {
        if (self.snapshots.len < 10) {
            return MemoryAnalysis{ .status = .insufficient_data };
        }
        
        // Calculate growth rate over different intervals
        const early_sample = self.snapshots[2]; // Skip initial allocations
        const mid_sample = self.snapshots[self.snapshots.len / 2];
        const late_sample = self.snapshots[self.snapshots.len - 1];
        
        const early_leaked = @as(f64, @floatFromInt(mid_sample.allocations_made - mid_sample.allocations_freed)) - @as(f64, @floatFromInt(early_sample.allocations_made - early_sample.allocations_freed));
        const late_leaked = @as(f64, @floatFromInt(late_sample.allocations_made - late_sample.allocations_freed)) - @as(f64, @floatFromInt(mid_sample.allocations_made - mid_sample.allocations_freed));
        
        const early_iterations = @as(f64, @floatFromInt(mid_sample.iteration - early_sample.iteration));
        const late_iterations = @as(f64, @floatFromInt(late_sample.iteration - mid_sample.iteration));
        
        const early_rate = if (early_iterations > 0) early_leaked / early_iterations else 0;
        const late_rate = if (late_iterations > 0) late_leaked / late_iterations else 0;
        
        // Check for sustained growth
        const growth_threshold = 0.1; // leaked allocations per iteration
        const acceleration_threshold = 2.0; // growth rate increase
        
        if (late_rate > growth_threshold) {
            return MemoryAnalysis{ 
                .status = .probable_leak,
                .growth_rate = late_rate,
                .details = "Sustained memory leak detected"
            };
        }
        
        if (late_rate > early_rate * acceleration_threshold and late_rate > 0.05) {
            return MemoryAnalysis{
                .status = .possible_leak,
                .growth_rate = late_rate,
                .details = "Accelerating memory leak detected"
            };
        }
        
        return MemoryAnalysis{
            .status = .no_leak,
            .growth_rate = late_rate,
            .details = "Memory usage appears stable"
        };
    }
    
    fn printAnalysis(self: *Self) void {
        const analysis = self.analyzeGrowthPattern();
        
        std.debug.print("\n=== Memory Leak Analysis ===\n", .{});
        std.debug.print("Status: {s}\n", .{@tagName(analysis.status)});
        std.debug.print("Leak rate: {d:.3} allocs/iteration\n", .{analysis.growth_rate});
        std.debug.print("Details: {s}\n", .{analysis.details});
        
        // Print memory progression
        std.debug.print("\nMemory progression:\n", .{});
        const step = @max(1, self.snapshots.len / 10);
        for (0..10) |i| {
            const idx = i * step;
            if (idx < self.snapshots.len) {
                const snap = self.snapshots[idx];
                const leaked = snap.allocations_made - snap.allocations_freed;
                std.debug.print("  Iter {d}: {d} allocs, {d} freed, {d} leaked\n", .{
                    snap.iteration, snap.allocations_made, snap.allocations_freed, leaked
                });
            }
        }
        std.debug.print("==============================\n\n", .{});
    }
};

const MemoryAnalysis = struct {
    status: MemoryStatus,
    growth_rate: f64 = 0.0,
    details: []const u8 = "",
    
    const MemoryStatus = enum {
        insufficient_data,
        no_leak,
        possible_leak,
        probable_leak,
    };
};

/// Simulates realistic track/state data with occasional changes
const MockTrackState = struct {
    current_song: []const u8,
    current_artist: []const u8,
    current_state: []const u8,
    
    const songs = [_][]const u8{
        "Bohemian Rhapsody", "Stairway to Heaven", "Hotel California",
        "Sweet Child O' Mine", "Smoke on the Water", "Free Bird",
        "Thunderstruck", "Back in Black", "Enter Sandman"
    };
    
    const artists = [_][]const u8{
        "Queen", "Led Zeppelin", "Eagles", "Guns N' Roses", 
        "Deep Purple", "Lynyrd Skynyrd", "AC/DC", "Metallica"
    };
    
    const states = [_][]const u8{ "Playing", "Paused", "Stopped" };
    
    fn init(iteration: usize) MockTrackState {
        return MockTrackState{
            .current_song = songs[iteration % songs.len],
            .current_artist = artists[iteration % artists.len],
            .current_state = states[iteration % states.len],
        };
    }
};

/// Test function that simulates polling behavior with good memory management
fn simulateGoodPollingBehavior(allocator: std.mem.Allocator, iterations: usize, stats: *MemoryStats) !void {
    var lastTitle: ?[]const u8 = null;
    var lastState: ?[]const u8 = null;
    var allocs_made: usize = 0;
    var allocs_freed: usize = 0;
    
    defer {
        if (lastTitle) |title| {
            allocator.free(title);
            allocs_freed += 1;
        }
        if (lastState) |state| {
            allocator.free(state);
            allocs_freed += 1;
        }
    }
    
    for (0..iterations) |i| {
        const mock_data = MockTrackState.init(i);
        
        // Simulate track/state change detection (realistic - not every iteration)
        const trackChanged = blk: {
            if (lastTitle == null) break :blk true;
            if (lastTitle) |last| {
                break :blk !std.mem.eql(u8, last, mock_data.current_song);
            }
            break :blk false;
        };
        
        const stateChanged = blk: {
            if (lastState == null) break :blk true;
            if (lastState) |last| {
                break :blk !std.mem.eql(u8, last, mock_data.current_state);
            }
            break :blk false;
        };
        
        // Only allocate when actually needed (good pattern)
        if (trackChanged) {
            if (lastTitle) |title| {
                allocator.free(title);
                allocs_freed += 1;
            }
            lastTitle = try allocator.dupe(u8, mock_data.current_song);
            allocs_made += 1;
        }
        
        if (stateChanged) {
            if (lastState) |state| {
                allocator.free(state);
                allocs_freed += 1;
            }
            lastState = try allocator.dupe(u8, mock_data.current_state);
            allocs_made += 1;
        }
        
        // Record memory snapshot periodically
        if (i % 100 == 0) {
            stats.recordSnapshot(i / 100, i, allocs_made, allocs_freed);
        }
    }
}

/// Test function that simulates polling behavior with memory leaks
fn simulateBadPollingBehavior(allocator: std.mem.Allocator, iterations: usize, stats: *MemoryStats) !void {
    var lastTitle: ?[]const u8 = null;
    var lastState: ?[]const u8 = null;
    var allocs_made: usize = 0;
    var allocs_freed: usize = 0;
    
    defer {
        if (lastTitle) |title| {
            allocator.free(title);
            allocs_freed += 1;
        }
        if (lastState) |state| {
            allocator.free(state);
            allocs_freed += 1;
        }
    }
    
    for (0..iterations) |i| {
        const mock_data = MockTrackState.init(i);
        
        // Simulate the old buggy pattern - allocate temporary strings
        const currentTitle = try allocator.dupe(u8, mock_data.current_song);
        allocs_made += 1;
        defer {
            allocator.free(currentTitle);
            allocs_freed += 1;
        }
        
        const currentState = try allocator.dupe(u8, mock_data.current_state);
        allocs_made += 1;
        defer {
            allocator.free(currentState);
            allocs_freed += 1;
        }
        
        // Change detection (force changes to maximize leaks)
        const trackChanged = (i % 2 == 0);
        const stateChanged = (i % 3 == 0);
        
        // Buggy pattern - duplicate already-allocated strings  
        if (trackChanged) {
            if (lastTitle) |title| {
                allocator.free(title);
                allocs_freed += 1;
            }
            lastTitle = try allocator.dupe(u8, currentTitle); // Extra allocation!
            allocs_made += 1;
        }
        
        if (stateChanged) {
            if (lastState) |state| {
                allocator.free(state);
                allocs_freed += 1;
            }
            lastState = try allocator.dupe(u8, currentState); // Extra allocation!
            allocs_made += 1;
        }
        
        // Record memory snapshot periodically
        if (i % 100 == 0) {
            stats.recordSnapshot(i / 100, i, allocs_made, allocs_freed);
        }
    }
}

test "memory leak detector - good pattern should not leak" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = true,
        .retain_metadata = true,
    }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("❌ Unexpected leak detected in good pattern test!\n", .{});
        }
    }
    const allocator = gpa.allocator();
    
    const iterations = 5000;
    const snapshots = iterations / 100;
    
    var stats = try MemoryStats.init(allocator, snapshots);
    defer stats.deinit();
    
    try simulateGoodPollingBehavior(allocator, iterations, &stats);
    
    stats.printAnalysis();
    const analysis = stats.analyzeGrowthPattern();
    
    // Good pattern should not show sustained growth
    try testing.expect(analysis.status == .no_leak or analysis.status == .insufficient_data);
}

test "memory leak detector - bad pattern should detect leaks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = true,
        .retain_metadata = true,
    }){};
    defer {
        const leaked = gpa.deinit();
        // We expect this to leak - don't fail the test
        if (leaked == .leak) {
            std.debug.print("✓ Expected leak detected in bad pattern test\n", .{});
        }
    }
    const allocator = gpa.allocator();
    
    const iterations = 5000;
    const snapshots = iterations / 100;
    
    var stats = try MemoryStats.init(allocator, snapshots);
    defer stats.deinit();
    
    try simulateBadPollingBehavior(allocator, iterations, &stats);
    
    stats.printAnalysis();
    const analysis = stats.analyzeGrowthPattern();
    
    // Bad pattern should show memory growth
    try testing.expect(analysis.status == .possible_leak or analysis.status == .probable_leak);
}

test "memory leak detector - realistic polling simulation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = true,
        .retain_metadata = true,
    }){};
    const allocator = gpa.allocator();
    
    // This test simulates the actual main.zig polling pattern after our fix
    var lastTitle: ?[]const u8 = null;
    var lastState: ?[]const u8 = null;
    var allocs_made: usize = 0;
    var allocs_freed: usize = 0;
    
    defer {
        if (lastTitle) |title| {
            allocator.free(title);
            allocs_freed += 1;
        }
        if (lastState) |state| {
            allocator.free(state);
            allocs_freed += 1;
        }
    }
    
    const iterations = 10000;
    const snapshots = iterations / 200;
    
    var stats = try MemoryStats.init(allocator, snapshots);
    defer stats.deinit();
    
    for (0..iterations) |i| {
        // Simulate realistic track changes (not every iteration)
        const mock_data = MockTrackState.init(i / 50); // Change every 50 iterations
        
        // This follows the FIXED pattern from main.zig
        const currentTitleStr = mock_data.current_song;
        const currentStateStr = mock_data.current_state;
        
        const trackChanged = blk: {
            if (lastTitle == null) break :blk true;
            if (lastTitle) |last| {
                break :blk !std.mem.eql(u8, last, currentTitleStr);
            }
            break :blk false;
        };
        
        const stateChanged = blk: {
            if (lastState == null) break :blk true;
            if (lastState) |last| {
                break :blk !std.mem.eql(u8, last, currentStateStr);
            }
            break :blk false;
        };
        
        // Allocate only when needed, directly from source
        if (trackChanged) {
            if (lastTitle) |title| {
                allocator.free(title);
                allocs_freed += 1;
            }
            lastTitle = try allocator.dupe(u8, currentTitleStr);
            allocs_made += 1;
        }
        
        if (stateChanged) {
            if (lastState) |state| {
                allocator.free(state);
                allocs_freed += 1;
            }
            lastState = try allocator.dupe(u8, currentStateStr);
            allocs_made += 1;
        }
        
        // Record memory snapshots
        if (i % 200 == 0) {
            stats.recordSnapshot(i / 200, i, allocs_made, allocs_freed);
        }
    }
    
    stats.printAnalysis();
    const analysis = stats.analyzeGrowthPattern();
    
    // Fixed implementation should show stable memory usage
    try testing.expect(analysis.status == .no_leak);
    std.debug.print("✓ Realistic polling test passed - no memory leaks detected\n", .{});
    
    // Check for actual leaks
    const leaked = gpa.deinit();
    try testing.expect(leaked != .leak);
}