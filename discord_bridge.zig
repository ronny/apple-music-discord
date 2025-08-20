const std = @import("std");
const print = std.debug.print;

// Discord Social SDK integration (required)
const DiscordClient = struct {
    // C Discord Social SDK bindings
    const c = @cImport({
        @cInclude("cdiscord.h");
    });
    
    client: c.Discord_Client,
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, client_id: i64) !Self {
        var self = Self{
            .allocator = allocator,
            .client = undefined,
        };
        
        // Initialize Discord client
        c.Discord_Client_Init(&self.client);
        
        // Set the application ID
        c.Discord_Client_SetApplicationId(&self.client, @intCast(client_id));
        
        // Connect to Discord's servers
        c.Discord_Client_Connect(&self.client);
        
        print("Discord client initialized and connecting with app ID: {}\n", .{client_id});
        return self;
    }
    
    pub fn deinit(self: *Self) void {
        c.Discord_Client_Disconnect(&self.client);
        c.Discord_Client_Drop(&self.client);
    }
    
    pub fn updateActivity(self: *Self, title: ?[]const u8, artist: ?[]const u8, state: []const u8, position_seconds: f64, duration_seconds: f64) !void {
        var activity: c.Discord_Activity = undefined;
        c.Discord_Activity_Init(&activity);
        defer c.Discord_Activity_Drop(&activity);
        
        // Set activity type to "Listening" for music
        c.Discord_Activity_SetType(&activity, c.Discord_ActivityTypes_Listening);
        
        // Set status display type to prioritize Details field for minimal display
        var display_type: c.Discord_StatusDisplayTypes = c.Discord_StatusDisplayTypes_Details;
        c.Discord_Activity_SetStatusDisplayType(&activity, &display_type);
        
        // Set name (song title) - this appears in minimal display
        if (title) |t| {
            const title_str: c.Discord_String = .{
                .ptr = @constCast(t.ptr),
                .size = t.len,
            };
            c.Discord_Activity_SetName(&activity, title_str);
        }
        
        // Set details (song title) - this appears in full display
        if (title) |t| {
            var title_str: c.Discord_String = .{
                .ptr = @constCast(t.ptr),
                .size = t.len,
            };
            c.Discord_Activity_SetDetails(&activity, @ptrCast(&title_str));
        }
        
        // Set state (artist name)
        if (artist) |a| {
            var artist_str: c.Discord_String = .{
                .ptr = @constCast(a.ptr),
                .size = a.len,
            };
            c.Discord_Activity_SetState(&activity, @ptrCast(&artist_str));
        }
        
        // Set timestamps for "Playing" state only, accounting for current position
        if (std.mem.eql(u8, state, "Playing") and position_seconds >= 0 and duration_seconds > 0) {
            var timestamps: c.Discord_ActivityTimestamps = undefined;
            c.Discord_ActivityTimestamps_Init(&timestamps);
            defer c.Discord_ActivityTimestamps_Drop(&timestamps);
            
            // Calculate start time by subtracting current position from now
            const now_seconds = @as(u64, @intCast(std.time.timestamp()));
            const position_ms = @as(u64, @intFromFloat(position_seconds * 1000.0));
            const start_time = now_seconds * 1000 - position_ms; // Discord expects milliseconds
            
            // Calculate end time by adding remaining duration to now
            const remaining_seconds = duration_seconds - position_seconds;
            const end_time = now_seconds * 1000 + @as(u64, @intFromFloat(remaining_seconds * 1000.0));
            
            c.Discord_ActivityTimestamps_SetStart(&timestamps, start_time);
            c.Discord_ActivityTimestamps_SetEnd(&timestamps, end_time);
            c.Discord_Activity_SetTimestamps(&activity, &timestamps);
        }
        
        // Update rich presence
        c.Discord_Client_UpdateRichPresence(&self.client, &activity, null, null, null);
        
        print("Discord activity updated: {s} - {s} [{s}]\n", .{ 
            if (title) |t| t else "Unknown", 
            if (artist) |a| a else "Unknown", 
            state 
        });
    }
    
    pub fn clearActivity(self: *Self) !void {
        c.Discord_Client_ClearRichPresence(&self.client);
        print("Discord activity cleared\n", .{});
    }
    
    pub fn runCallbacks(self: *Self) void {
        // Check client status before running callbacks
        const status = c.Discord_Client_GetStatus(&self.client);
        if (status == c.Discord_Client_Status_Disconnected) {
            // Don't run callbacks when disconnected
            return;
        }
        
        // NOTE: Discord_RunCallbacks() causes segmentation fault in this version
        // of the Discord Social SDK. The basic rich presence functionality works
        // without it as the SDK handles callbacks internally.
        // TODO: Investigate proper callback initialization for future versions
        // c.Discord_RunCallbacks();
    }
};

pub const Discord = DiscordClient;