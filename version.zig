// Static version file - git info comes from build options
const std = @import("std");
const config = @import("config");

pub fn getVersion(allocator: std.mem.Allocator) ![]const u8 {
    const debug_prefix = if (config.optimize_mode == .Debug) "debug-" else "";
    return std.fmt.allocPrint(allocator, "{s}{s}-{s}-{s}", .{ debug_prefix, config.git_ref, config.git_date, config.git_hash });
}

pub const build_mode = @tagName(config.optimize_mode);