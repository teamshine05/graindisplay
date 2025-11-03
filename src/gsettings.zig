//! gsettings: interface to GNOME settings daemon
//!
//! How do we actually change the display settings? GNOME stores
//! them in something called "gsettings" - a system for managing
//! application and desktop preferences.
//!
//! We use the `gsettings` command-line tool to read and write
//! these values. It's safe, it's standard, and it works reliably
//! on Ubuntu 24.04 LTS with GNOME Wayland.

const std = @import("std");
const types = @import("types.zig");

// GNOME settings schema for color/Night Light.
//
// This is the "address" where GNOME stores Night Light settings.
const COLOR_SCHEMA = "org.gnome.settings-daemon.plugins.color";

// Read a boolean value from gsettings.
//
// Returns the value if successful, or an error if reading failed.
// Does this make sense? We're asking gsettings "what is this setting?"
// and it gives us back true or false.
fn read_bool(allocator: std.mem.Allocator, key: []const u8) !bool {
    const result = try exec_gsettings(allocator, &[_][]const u8{ "get", COLOR_SCHEMA, key });
    defer allocator.free(result);

    // gsettings returns "true" or "false" as strings
    if (std.mem.eql(u8, std.mem.trim(u8, result, &std.ascii.whitespace), "true")) {
        return true;
    } else {
        return false;
    }
}

// Write a boolean value to gsettings.
//
// This actually changes the setting! We're telling gsettings
// "set this key to this value, please."
fn write_bool(key: []const u8, value: bool) !void {
    const value_str = if (value) "true" else "false";
    _ = try exec_gsettings(null, &[_][]const u8{ "set", COLOR_SCHEMA, key, value_str });
}

// Read a uint32 value from gsettings.
fn read_u32(allocator: std.mem.Allocator, key: []const u8) !u32 {
    const result = try exec_gsettings(allocator, &[_][]const u8{ "get", COLOR_SCHEMA, key });
    defer allocator.free(result);

    // gsettings returns numbers as "uint32 2700" - we need to extract the number part
    var trimmed = std.mem.trim(u8, result, &std.ascii.whitespace);
    
    // Skip "uint32 " prefix if present (or "int32 " or just the number)
    if (std.mem.indexOf(u8, trimmed, " ")) |space_idx| {
        trimmed = trimmed[space_idx + 1 ..];
        trimmed = std.mem.trim(u8, trimmed, &std.ascii.whitespace);
    }
    
    if (trimmed.len == 0) {
        return error.InvalidFormat;
    }
    
    return try std.fmt.parseInt(u32, trimmed, 10);
}

// Write a uint32 value to gsettings.
fn write_u32(key: []const u8, value: u32) !void {
    const value_str = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{value});
    defer std.heap.page_allocator.free(value_str);
    _ = try exec_gsettings(null, &[_][]const u8{ "set", COLOR_SCHEMA, key, value_str });
}

// Read a double (f64) value from gsettings.
fn read_f64(allocator: std.mem.Allocator, key: []const u8) !f64 {
    const result = try exec_gsettings(allocator, &[_][]const u8{ "get", COLOR_SCHEMA, key });
    defer allocator.free(result);

    // gsettings returns numbers as "double 18.0" - we need to extract the number part
    var trimmed = std.mem.trim(u8, result, &std.ascii.whitespace);
    
    // Skip type prefix if present (like "double " or "float ")
    if (std.mem.indexOf(u8, trimmed, " ")) |space_idx| {
        trimmed = trimmed[space_idx + 1 ..];
        trimmed = std.mem.trim(u8, trimmed, &std.ascii.whitespace);
    }
    
    if (trimmed.len == 0) {
        return error.InvalidFormat;
    }
    
    return try std.fmt.parseFloat(f64, trimmed);
}

// Write a double (f64) value to gsettings.
fn write_f64(key: []const u8, value: f64) !void {
    const value_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value});
    defer std.heap.page_allocator.free(value_str);
    _ = try exec_gsettings(null, &[_][]const u8{ "set", COLOR_SCHEMA, key, value_str });
}

// Execute gsettings command and return output.
//
// This is our helper function that runs gsettings and captures
// what it prints. We use it for reading values.
//
// Why this pattern? Because gsettings is an external program,
// we need to run it as a subprocess and read its output.
fn exec_gsettings(
    allocator: ?std.mem.Allocator,
    args: []const []const u8,
) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Build the full command: ["gsettings", ...args]
    var full_args = std.ArrayList([]const u8).initCapacity(arena_allocator, 16) catch return error.OutOfMemory;
    try full_args.append(arena_allocator, "gsettings");
    try full_args.appendSlice(arena_allocator, args);

    // Run gsettings and capture output
    const result = try std.process.Child.run(.{
        .allocator = arena_allocator,
        .argv = full_args.items,
        .max_output_bytes = 1024,
    });

    // Check if command succeeded
    switch (result.term) {
        .Exited => |code| {
            if (code != 0) {
                return error.GSettingsFailed;
            }
        },
        else => return error.GSettingsFailed,
    }

    // If caller wants the output, copy it to their allocator
    if (allocator) |alloc| {
        return try alloc.dupe(u8, result.stdout);
    } else {
        // Caller doesn't need output (write operation)
        return "";
    }
}

// Apply a Night Light configuration to the system.
//
// This is the main function you'll use! It takes your configuration
// and actually changes the GNOME settings to match it.
//
// Example:
//   try apply_config(std.heap.page_allocator, types.default_warm);
//
// Does this make sense? We're taking the values from our config
// structure and telling GNOME "please use these settings!"
//
// Note: allocator parameter is kept for API consistency, even though
// we don't need it for write operations. This makes the function
// signature consistent with read_config which does need allocation.
pub fn apply_config(
    allocator: std.mem.Allocator,
    config: types.NightLightConfig,
) !void {
    _ = allocator; // Not used for write operations, but kept for consistency
    // Enable or disable Night Light
    try write_bool("night-light-enabled", config.enabled);

    // Set the temperature (warmth level)
    try write_u32("night-light-temperature", config.temperature);

    // Set automatic schedule preference
    try write_bool("night-light-schedule-automatic", config.schedule_automatic);

    // If not automatic, set manual schedule times
    if (!config.schedule_automatic) {
        try write_f64("night-light-schedule-from", config.schedule_from);
        try write_f64("night-light-schedule-to", config.schedule_to);
    }
}

// Read current Night Light configuration from the system.
//
// This lets you check what the current settings are. Useful for
// seeing what's already configured!
pub fn read_config(allocator: std.mem.Allocator) !types.NightLightConfig {
    return types.NightLightConfig{
        .enabled = try read_bool(allocator, "night-light-enabled"),
        .temperature = try read_u32(allocator, "night-light-temperature"),
        .schedule_automatic = try read_bool(allocator, "night-light-schedule-automatic"),
        .schedule_from = try read_f64(allocator, "night-light-schedule-from"),
        .schedule_to = try read_f64(allocator, "night-light-schedule-to"),
    };
}

// Apply a full display configuration (including color modes).
//
// This handles both Night Light settings and special color modes
// like monochrome or red-green filters.
pub fn apply_display_config(
    allocator: std.mem.Allocator,
    config: types.DisplayConfig,
) !void {
    // Always apply Night Light settings first
    try apply_config(allocator, config.night_light);

    // Then apply color mode if needed
    switch (config.mode) {
        .normal => {
            // Normal mode - no special color filtering needed
            // Night Light temperature adjustment is already applied above
        },
        .monochrome => {
            // Monochrome (grayscale) mode
            // Note: This requires Wayland protocol support
            // On GNOME Wayland, we can use wlr-gamma-control protocol
            // For now, we document this and can expand later
            // TODO: Implement monochrome via Wayland color management protocols
            // Future: Use wlr-gamma-control or similar to set grayscale LUT
            // allocator will be needed when we implement this feature
        },
        .red_green => {
            // Red-green only mode (no blue channel)
            // This is useful for colorblind accessibility or special display needs
            // TODO: Implement red-green filter via Wayland color management protocols
            // Future: Use wlr-gamma-control to zero blue channel, max red/green
            // allocator will be needed when we implement this feature
        },
    }
}

