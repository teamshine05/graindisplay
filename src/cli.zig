//! cli: command line interface for graindisplay
//!
//! This tool helps you configure your display's Night Light
//! settings interactively or from command line arguments.
//!
//! You can use full flags (--full) or short flags (-f) - both
//! work the same way! This makes it easy to use both in scripts
//! and when typing commands quickly.

const std = @import("std");
const graindisplay = @import("graindisplay.zig");

// Command line options for graindisplay.
//
// We use full word names internally for clarity (like "interactive"
// and "full"), but support short options on the command line
// for convenience (like "-i" and "-f").
const Options = struct {
    interactive: bool = false, // -i or --interactive
    full: bool = false, // -f or --full (show full config)
    enable: ?bool = null, // --enable or --disable
    temperature: ?u32 = null, // -t or --temperature
    preset: ?[]const u8 = null, // -p or --preset
    mode: ?graindisplay.DisplayMode = null, // -m or --mode (normal, monochrome, red-green)
};

// Parse command line arguments into options.
//
// Supports both short flags (-f) and long flags (--full).
// Returns null if help was requested or parsing failed.
fn parse_args(
    allocator: std.mem.Allocator,
) !?Options {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var opts = Options{};

    // Skip program name
    _ = args.skip();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-i") or
            std.mem.eql(u8, arg, "--interactive"))
        {
            opts.interactive = true;
        } else if (std.mem.eql(u8, arg, "-f") or
            std.mem.eql(u8, arg, "--full"))
        {
            opts.full = true;
        } else if (std.mem.eql(u8, arg, "--enable")) {
            opts.enable = true;
        } else if (std.mem.eql(u8, arg, "--disable")) {
            opts.enable = false;
        } else if (std.mem.eql(u8, arg, "-t") or
            std.mem.eql(u8, arg, "--temperature"))
        {
            const temp_str = args.next() orelse {
                std.debug.print("Error: --temperature requires a value\n", .{});
                return null;
            };
            opts.temperature = try std.fmt.parseInt(u32, temp_str, 10);
        } else if (std.mem.eql(u8, arg, "-p") or
            std.mem.eql(u8, arg, "--preset"))
        {
            opts.preset = args.next();
        } else if (std.mem.eql(u8, arg, "-m") or
            std.mem.eql(u8, arg, "--mode"))
        {
            const mode_str = args.next() orelse {
                std.debug.print("Error: --mode requires a value\n", .{});
                return null;
            };
            if (std.mem.eql(u8, mode_str, "normal")) {
                opts.mode = .normal;
            } else if (std.mem.eql(u8, mode_str, "monochrome")) {
                opts.mode = .monochrome;
            } else if (std.mem.eql(u8, mode_str, "red-green")) {
                opts.mode = .red_green;
            } else {
                std.debug.print("Error: unknown mode '{s}'\n", .{mode_str});
                std.debug.print("Available modes: normal, monochrome, red-green\n", .{});
                return null;
            }
        } else if (std.mem.eql(u8, arg, "--help") or
            std.mem.eql(u8, arg, "-h"))
        {
            try print_usage();
            return null;
        } else {
            std.debug.print("Unknown option: {s}\n", .{arg});
            try print_usage();
            return null;
        }
    }

    return opts;
}

// Print usage information.
fn print_usage() !void {
    std.debug.print(
        \\graindisplay - warm display configuration for Wayland Night Light
        \\
        \\Usage:
        \\  graindisplay [options]
        \\  graindisplay --interactive
        \\  graindisplay -f
        \\
        \\Options:
        \\  -i, --interactive       Interactive mode (prompts for values)
        \\  -f, --full              Show full current configuration
        \\      --enable            Enable Night Light
        \\      --disable           Disable Night Light
        \\  -t, --temperature TEMP  Set color temperature (1700-4700K)
        \\  -p, --preset PRESET     Apply preset
        \\  -m, --mode MODE         Set color mode (normal, monochrome, red-green)
        \\      --help              Show this help
        \\
        \\Presets:
        \\  default-warm     Balanced warmth (3000K)
        \\  very-warm        Extra warm (2500K)
        \\  warmer           Warm reading lamp (2800K)
        \\  most-warm        Warmest possible (1700K)
        \\  moderate-warm    Gentle warmth (4000K)
        \\  daylight-movie   Subtle warmth for movies (4500K)
        \\
        \\Examples:
        \\  graindisplay --interactive
        \\  graindisplay -f
        \\  graindisplay --preset most-warm
        \\  graindisplay --preset daylight-movie
        \\  graindisplay --mode monochrome
        \\  graindisplay --mode red-green
        \\  graindisplay --temperature 3000
        \\  graindisplay --enable
        \\
        \\
    , .{});
}

// Run interactive mode, prompting for each value.
fn run_interactive(
    allocator: std.mem.Allocator,
) !void {
    const stdin_fd = std.posix.STDIN_FILENO;
    const stdout_fd = std.posix.STDOUT_FILENO;

    try writeStr(stdout_fd, "Welcome to graindisplay! Let's configure your warm display.\n\n");

    // Read current config first
    const current = try graindisplay.read_config(allocator);
    try writeStr(stdout_fd, "Current settings:\n");
    const enabled_str = try std.fmt.allocPrint(allocator, "  Enabled: {}\n", .{current.enabled});
    defer allocator.free(enabled_str);
    try writeStr(stdout_fd, enabled_str);
    
    const temp_str = try std.fmt.allocPrint(allocator, "  Temperature: {}K\n", .{current.temperature});
    defer allocator.free(temp_str);
    try writeStr(stdout_fd, temp_str);
    
    const schedule_str = try std.fmt.allocPrint(allocator, "  Schedule automatic: {}\n\n", .{current.schedule_automatic});
    defer allocator.free(schedule_str);
    try writeStr(stdout_fd, schedule_str);

    // Enable/disable
    const prompt_enabled = if (current.enabled) "y" else "n";
    const enable_prompt = try std.fmt.allocPrint(allocator, "Enable Night Light? (y/n, default: {s}): ", .{prompt_enabled});
    defer allocator.free(enable_prompt);
    try writeStr(stdout_fd, enable_prompt);
    
    var stdin_buf: [256]u8 = undefined;
    const enable_bytes = try std.posix.read(stdin_fd, &stdin_buf);
    const enable_line = std.mem.trim(u8, stdin_buf[0..enable_bytes], &std.ascii.whitespace);
    const enabled = if (enable_line.len == 0) current.enabled else (enable_line[0] == 'y' or enable_line[0] == 'Y');

    // Temperature
    const temp_prompt = try std.fmt.allocPrint(allocator, "Temperature in Kelvins (1700-4700, default: {}): ", .{current.temperature});
    defer allocator.free(temp_prompt);
    try writeStr(stdout_fd, temp_prompt);
    
    const temp_bytes = try std.posix.read(stdin_fd, &stdin_buf);
    const temp_line = std.mem.trim(u8, stdin_buf[0..temp_bytes], &std.ascii.whitespace);
    const temperature = if (temp_line.len == 0) current.temperature else try std.fmt.parseInt(u32, temp_line, 10);

    // Apply the configuration
    const config = graindisplay.NightLightConfig{
        .enabled = enabled,
        .temperature = temperature,
        .schedule_automatic = current.schedule_automatic,
        .schedule_from = current.schedule_from,
        .schedule_to = current.schedule_to,
    };

    try graindisplay.apply_config(allocator, config);
    try writeStr(stdout_fd, "\n✅ Configuration applied!\n");
}

// Helper to write string to file descriptor.
fn writeStr(fd: std.posix.fd_t, str: []const u8) !void {
    _ = try std.posix.write(fd, str);
}

// Show full current configuration.
fn show_full(allocator: std.mem.Allocator) !void {
    const stdout_fd = std.posix.STDOUT_FILENO;
    const config = try graindisplay.read_config(allocator);

    try writeStr(stdout_fd, "Current Night Light Configuration:\n");
    const enabled_line = try std.fmt.allocPrint(allocator, "  Enabled: {}\n", .{config.enabled});
    defer allocator.free(enabled_line);
    try writeStr(stdout_fd, enabled_line);
    
    const temp_prefix = try std.fmt.allocPrint(allocator, "  Temperature: {}K (", .{config.temperature});
    defer allocator.free(temp_prefix);
    try writeStr(stdout_fd, temp_prefix);
    
    if (config.temperature <= 2500) {
        try writeStr(stdout_fd, "very warm");
    } else if (config.temperature <= 3000) {
        try writeStr(stdout_fd, "warm");
    } else if (config.temperature <= 4000) {
        try writeStr(stdout_fd, "moderate");
    } else {
        try writeStr(stdout_fd, "cool");
    }
    try writeStr(stdout_fd, ")\n");
    
    const schedule_auto = try std.fmt.allocPrint(allocator, "  Schedule automatic: {}\n", .{config.schedule_automatic});
    defer allocator.free(schedule_auto);
    try writeStr(stdout_fd, schedule_auto);
    
    if (!config.schedule_automatic) {
        const from_line = try std.fmt.allocPrint(allocator, "  Schedule from: {d:.1}h\n", .{config.schedule_from});
        defer allocator.free(from_line);
        try writeStr(stdout_fd, from_line);
        
        const to_line = try std.fmt.allocPrint(allocator, "  Schedule to: {d:.1}h\n", .{config.schedule_to});
        defer allocator.free(to_line);
        try writeStr(stdout_fd, to_line);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const opts = try parse_args(allocator) orelse return;

    // Handle different modes
    if (opts.full) {
        try show_full(allocator);
        return;
    }

    if (opts.interactive) {
        try run_interactive(allocator);
        return;
    }

    // Non-interactive mode: apply settings from command line
    var display_config = graindisplay.DisplayConfig{
        .night_light = try graindisplay.read_config(allocator),
    };

    // Apply preset if specified
    if (opts.preset) |preset| {
        if (std.mem.eql(u8, preset, "default-warm")) {
            display_config.night_light = graindisplay.default_warm;
        } else if (std.mem.eql(u8, preset, "very-warm")) {
            display_config.night_light = graindisplay.very_warm;
        } else if (std.mem.eql(u8, preset, "moderate-warm")) {
            display_config.night_light = graindisplay.moderate_warm;
        } else if (std.mem.eql(u8, preset, "warmer")) {
            display_config.night_light = graindisplay.warmer;
        } else if (std.mem.eql(u8, preset, "most-warm")) {
            display_config.night_light = graindisplay.most_warm;
        } else if (std.mem.eql(u8, preset, "daylight-movie")) {
            display_config.night_light = graindisplay.daylight_movie;
        } else {
            std.debug.print("Unknown preset: {s}\n", .{preset});
            std.debug.print("Available presets: default-warm, very-warm, warmer, most-warm, moderate-warm, daylight-movie\n", .{});
            return;
        }
    }

    // Override with command line options
    if (opts.enable) |enabled| {
        display_config.night_light.enabled = enabled;
    }
    if (opts.temperature) |temp| {
        display_config.night_light.temperature = temp;
    }
    if (opts.mode) |mode| {
        display_config.mode = mode;
    }

    // Apply the configuration
    try graindisplay.apply_display_config(allocator, display_config);

    const stdout_fd = std.posix.STDOUT_FILENO;
    try writeStr(stdout_fd, "✅ Configuration applied!\n");
    if (display_config.mode != .normal) {
        try writeStr(stdout_fd, "Note: Special color modes (monochrome/red-green) may require additional Wayland protocol support.\n");
    }
}

