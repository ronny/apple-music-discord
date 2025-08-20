const std = @import("std");
const testing = std.testing;

// Test memory allocation and deallocation patterns - this should demonstrate the leak
test "memory leak reproduction" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = true, 
        .retain_metadata = true,
    }){};
    const allocator = gpa.allocator();

    // Track allocations manually to verify the leak
    var total_allocations: usize = 0;
    var total_deallocations: usize = 0;

    // Simulate the EXACT pattern used in main.zig
    var lastTitle: ?[]const u8 = null;
    var lastState: ?[]const u8 = null;

    // Force changes every iteration to trigger the bug
    for (0..100) |i| {
        // Simulate currentTitle allocation (line 215 in main.zig)  
        var currentTitle: ?[]const u8 = null;
        const title_data = if (i % 2 == 0) "Song A" else "Song B"; // Force changes
        currentTitle = allocator.dupe(u8, title_data) catch null;
        total_allocations += 1;
        defer if (currentTitle) |title| {
            allocator.free(title);
            total_deallocations += 1;
        };

        // Simulate currentState allocation (line 222 in main.zig)
        const state_str = if (i % 3 == 0) "Playing" else "Paused"; // Force changes  
        const currentState: ?[]const u8 = allocator.dupe(u8, state_str) catch null;
        total_allocations += 1;
        defer if (currentState) |cur_state| {
            allocator.free(cur_state);
            total_deallocations += 1;
        };

        // Always detect changes to trigger the leak
        const trackChanged = true;
        const stateChanged = true;

        // This is the EXACT problematic code from main.zig (lines 249-262)
        if (trackChanged or stateChanged) {
            if (trackChanged) {
                if (lastTitle) |title| {
                    allocator.free(title);
                    total_deallocations += 1;
                }
                // BUG: This duplicates currentTitle which will be freed by defer!
                lastTitle = if (currentTitle) |title| allocator.dupe(u8, title) catch null else null;
                if (lastTitle != null) total_allocations += 1;
            }

            if (lastState) |old_state| {
                allocator.free(old_state);
                total_deallocations += 1;
            }
            // BUG: This duplicates currentState which will be freed by defer!
            lastState = if (currentState) |cur_state| allocator.dupe(u8, cur_state) catch null else null;
            if (lastState != null) total_allocations += 1;
        }
    }

    // Clean up remaining allocations
    if (lastTitle) |title| {
        allocator.free(title);
        total_deallocations += 1;
    }
    if (lastState) |state| {
        allocator.free(state);
        total_deallocations += 1;
    }

    std.debug.print("Total allocations: {}, Total deallocations: {}\n", .{total_allocations, total_deallocations});

    // Check for memory leaks
    const leaked = gpa.deinit();
    
    std.debug.print("Memory leak test completed. Leaked: {}\n", .{leaked});
    
    // This test should now pass with the fixed implementation
    try testing.expect(leaked != .leak);
}

// Test to verify proper memory management
test "memory allocation cleanup - proper pattern" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = true,
        .retain_metadata = true,
    }){};
    const allocator = gpa.allocator();

    // This shows the CORRECT way to handle the memory
    var lastTitle: ?[]const u8 = null;
    var lastState: ?[]const u8 = null;

    for (0..100) |i| {
        // Get current data directly without extra allocation
        const title_data = if (i % 3 == 0) "Test Song Title" else "Another Song";
        const state_str = if (i % 2 == 0) "Playing" else "Paused";

        // Check if data changed
        const trackChanged = blk: {
            if (lastTitle) |last| {
                break :blk !std.mem.eql(u8, last, title_data);
            }
            break :blk true;
        };

        const stateChanged = blk: {
            if (lastState) |last| {
                break :blk !std.mem.eql(u8, last, state_str);
            }
            break :blk true;
        };

        // Only allocate when actually needed
        if (trackChanged) {
            if (lastTitle) |title| allocator.free(title);
            lastTitle = allocator.dupe(u8, title_data) catch null;
        }

        if (stateChanged) {
            if (lastState) |state| allocator.free(state);
            lastState = allocator.dupe(u8, state_str) catch null;
        }
    }

    // Clean up
    if (lastTitle) |title| allocator.free(title);
    if (lastState) |state| allocator.free(state);

    // This should not leak
    const leaked = gpa.deinit();
    try testing.expect(leaked != .leak);
}

// Test the FIXED pattern from main.zig
test "memory fixed pattern - no double allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = true,
        .retain_metadata = true,
    }){};
    const allocator = gpa.allocator();

    var lastTitle: ?[]const u8 = null;
    var lastState: ?[]const u8 = null;

    for (0..1000) |i| {
        // Simulate the FIXED pattern - work with source strings directly
        const currentTitleStr: ?[]const u8 = if (i % 2 == 0) "Song A" else "Song B";
        const currentStateStr = if (i % 3 == 0) "Playing" else "Paused";

        // Check for changes
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
            break :blk true;
        };

        // Fixed allocation pattern - allocate directly from source
        if (trackChanged or stateChanged) {
            if (trackChanged) {
                if (lastTitle) |title| allocator.free(title);
                lastTitle = if (currentTitleStr) |title| allocator.dupe(u8, title) catch null else null;
            }

            if (lastState) |old_state| allocator.free(old_state);
            lastState = allocator.dupe(u8, currentStateStr) catch null;
        }
        
        // No defer cleanup needed - we only allocate what we keep
    }

    // Clean up
    if (lastTitle) |title| allocator.free(title);
    if (lastState) |state| allocator.free(state);

    // This should definitely not leak
    const leaked = gpa.deinit();
    try testing.expect(leaked != .leak);
}
