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
    
    pub fn updateActivity(self: *Self, title: ?[]const u8, artist: ?[]const u8, state: []const u8) !void {
        var activity: c.Discord_Activity = undefined;
        c.Discord_Activity_Init(&activity);
        defer c.Discord_Activity_Drop(&activity);
        
        // Set activity type to "Listening"
        c.Discord_Activity_SetType(&activity, c.Discord_ActivityTypes_Listening);
        
        // Set details (song title)
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
        
        // Set timestamps for "Playing" state
        if (std.mem.eql(u8, state, "Playing")) {
            var timestamps: c.Discord_ActivityTimestamps = undefined;
            c.Discord_ActivityTimestamps_Init(&timestamps);
            defer c.Discord_ActivityTimestamps_Drop(&timestamps);
            
            const now = @as(u64, @intCast(std.time.timestamp()));
            c.Discord_ActivityTimestamps_SetStart(&timestamps, now);
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