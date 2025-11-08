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
const config = @import("config.zig");

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
    font_scale: ?f64 = null, // --font-scale or --font-scale-175
};

// Parse command line arguments into options.
//
// Supports both short flags (-f) and long flags (--full).
// Returns null if help was requested or parsing failed.
fn parse_args_list(
    allocator: std.mem.Allocator,
    list: []const []const u8,
) !?Options {
    var opts = Options{};
    if (list.len == 0) return opts;

    var i: usize = 1; // skip program name
    while (i < list.len) : (i += 1) {
        const arg = list[i];
        if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--interactive")) {
            opts.interactive = true;
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--full")) {
            opts.full = true;
        } else if (std.mem.eql(u8, arg, "--enable")) {
            opts.enable = true;
        } else if (std.mem.eql(u8, arg, "--disable")) {
            opts.enable = false;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--temperature")) {
            i += 1;
            if (i >= list.len) {
                std.debug.print("Error: --temperature requires a value\n", .{});
                return null;
            }
            opts.temperature = try std.fmt.parseInt(u32, list[i], 10);
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--preset")) {
            i += 1;
            if (i >= list.len) {
                std.debug.print("Error: --preset requires a value\n", .{});
                return null;
            }
            opts.preset = list[i];
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--mode")) {
            i += 1;
            if (i >= list.len) {
                std.debug.print("Error: --mode requires a value\n", .{});
                return null;
            }
            const mode_str = list[i];
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
        } else if (std.mem.eql(u8, arg, "--font-scale")) {
            i += 1;
            if (i >= list.len) {
                std.debug.print("Error: --font-scale requires a value\n", .{});
                return null;
            }
            opts.font_scale = try std.fmt.parseFloat(f64, list[i]);
        } else if (std.mem.eql(u8, arg, "--font-scale-175")) {
            opts.font_scale = 1.75;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try print_usage();
            return null;
        } else {
            std.debug.print("Unknown option: {s}\n", .{arg});
            try print_usage();
            return null;
        }
    }

    _ = allocator;
    return opts;
}

fn parse_args(
    allocator: std.mem.Allocator,
) !?Options {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    return try parse_args_list(allocator, args);
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
        \\      --font-scale VALUE  Set Wayland text scaling factor (e.g. 1.75)
        \\      --font-scale-175    Shortcut for 1.75x text scaling
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
        \\  graindisplay --font-scale 1.75
        \\  graindisplay --font-scale-175
        \\
        \\
    , .{});
}

// Run interactive mode, prompting for each value.
fn run_interactive(
    allocator: std.mem.Allocator,
    client: *graindisplay.Client,
) !void {
    const stdin_fd = std.posix.STDIN_FILENO;
    const stdout_fd = std.posix.STDOUT_FILENO;

    try writeStr(stdout_fd, "Welcome to graindisplay! Let's configure your warm display.\n\n");

    // Read current config first
    const current = try client.readNightLight();
    const current_interface = try client.readInterface();
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

    const scale_str = try std.fmt.allocPrint(allocator, "Current text scaling: {d:.2}x\n\n", .{current_interface.text_scale});
    defer allocator.free(scale_str);
    try writeStr(stdout_fd, scale_str);

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

    // Text scaling
    const scale_prompt = try std.fmt.allocPrint(
        allocator,
        "Text scaling factor (default: {d:.2}) [press enter to keep]: ",
        .{current_interface.text_scale},
    );
    defer allocator.free(scale_prompt);
    try writeStr(stdout_fd, scale_prompt);

    const scale_bytes = try std.posix.read(stdin_fd, &stdin_buf);
    const scale_line = std.mem.trim(u8, stdin_buf[0..scale_bytes], &std.ascii.whitespace);
    var interface_config = current_interface;
    var interface_changed = false;
    if (scale_line.len != 0) {
        interface_config.text_scale = try std.fmt.parseFloat(f64, scale_line);
        interface_changed = true;
    }

    // Apply the configuration
    const interactive_config = graindisplay.NightLightConfig{
        .enabled = enabled,
        .temperature = temperature,
        .schedule_automatic = current.schedule_automatic,
        .schedule_from = current.schedule_from,
        .schedule_to = current.schedule_to,
    };

    try client.applyNightLight(interactive_config);
    if (interface_changed) {
        try client.applyInterface(interface_config);
    }
    try writeStr(stdout_fd, "\n✅ Configuration applied!\n");
    if (interface_changed) {
        try writeStr(stdout_fd, "Text scaling updated successfully.\n");
    }
}

// Helper to write string to file descriptor.
fn writeStr(fd: std.posix.fd_t, str: []const u8) !void {
    _ = try std.posix.write(fd, str);
}

// Show full current configuration.
fn show_full(allocator: std.mem.Allocator, client: *graindisplay.Client) !void {
    const stdout_fd = std.posix.STDOUT_FILENO;
    const current_config = try client.readNightLight();
    const interface_config = try client.readInterface();

    try writeStr(stdout_fd, "Current Night Light Configuration:\n");
    const enabled_line = try std.fmt.allocPrint(allocator, "  Enabled: {}\n", .{current_config.enabled});
    defer allocator.free(enabled_line);
    try writeStr(stdout_fd, enabled_line);

    const temp_prefix = try std.fmt.allocPrint(allocator, "  Temperature: {}K (", .{current_config.temperature});
    defer allocator.free(temp_prefix);
    try writeStr(stdout_fd, temp_prefix);

    if (current_config.temperature <= 2500) {
        try writeStr(stdout_fd, "very warm");
    } else if (current_config.temperature <= 3000) {
        try writeStr(stdout_fd, "warm");
    } else if (current_config.temperature <= 4000) {
        try writeStr(stdout_fd, "moderate");
    } else {
        try writeStr(stdout_fd, "cool");
    }
    try writeStr(stdout_fd, ")\n");

    const schedule_auto = try std.fmt.allocPrint(allocator, "  Schedule automatic: {}\n", .{current_config.schedule_automatic});
    defer allocator.free(schedule_auto);
    try writeStr(stdout_fd, schedule_auto);

    if (!current_config.schedule_automatic) {
        const from_line = try std.fmt.allocPrint(allocator, "  Schedule from: {d:.1}h\n", .{current_config.schedule_from});
        defer allocator.free(from_line);
        try writeStr(stdout_fd, from_line);

        const to_line = try std.fmt.allocPrint(allocator, "  Schedule to: {d:.1}h\n", .{current_config.schedule_to});
        defer allocator.free(to_line);
        try writeStr(stdout_fd, to_line);
    }

    const scale_line = try std.fmt.allocPrint(allocator, "\nCurrent text scaling: {d:.2}x\n", .{interface_config.text_scale});
    defer allocator.free(scale_line);
    try writeStr(stdout_fd, scale_line);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const opts = try parse_args(allocator) orelse return;
    var client = graindisplay.open(allocator);

    // Handle different modes
    if (opts.full) {
        try show_full(allocator, &client);
        return;
    }

    if (opts.interactive) {
        try run_interactive(allocator, &client);
        return;
    }

    // Non-interactive mode: apply settings from command line
    var display_config = graindisplay.DisplayConfig{
        .night_light = try client.readNightLight(),
    };
    var interface_config = try client.readInterface();

    if (try config.loadDefault(allocator)) |preferences| {
        applyPreferences(&display_config, &interface_config, preferences);
    }

    // Apply preset if specified
    if (opts.preset) |preset| {
        if (presetByName(preset)) |resolved| {
            display_config.night_light = resolved;
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
    if (opts.font_scale) |scale| {
        if (scale <= 0) {
            std.debug.print("Error: text scaling must be positive\n", .{});
            return;
        }
        interface_config.text_scale = scale;
    }

    // Apply the configuration
    try client.applyDisplay(display_config);
    try client.applyInterface(interface_config);

    const stdout_fd = std.posix.STDOUT_FILENO;
    try writeStr(stdout_fd, "✅ Configuration applied!\n");
    if (opts.font_scale != null) {
        try writeStr(stdout_fd, "Text scaling updated.\n");
    }
    if (display_config.mode != .normal) {
        try writeStr(stdout_fd, "Note: Special color modes (monochrome/red-green) may require additional Wayland protocol support.\n");
    }
}

fn presetByName(name: []const u8) ?graindisplay.NightLightConfig {
    if (std.mem.eql(u8, name, "default-warm")) return graindisplay.default_warm;
    if (std.mem.eql(u8, name, "very-warm")) return graindisplay.very_warm;
    if (std.mem.eql(u8, name, "moderate-warm")) return graindisplay.moderate_warm;
    if (std.mem.eql(u8, name, "warmer")) return graindisplay.warmer;
    if (std.mem.eql(u8, name, "most-warm")) return graindisplay.most_warm;
    if (std.mem.eql(u8, name, "daylight-movie")) return graindisplay.daylight_movie;
    return null;
}

fn applyPreferences(
    display_config: *graindisplay.DisplayConfig,
    interface_config: *graindisplay.InterfaceConfig,
    preferences: config.Preference,
) void {
    if (preferences.preset) |preset| {
        const resolved = switch (preset) {
            .default_warm => graindisplay.default_warm,
            .very_warm => graindisplay.very_warm,
            .moderate_warm => graindisplay.moderate_warm,
            .warmer => graindisplay.warmer,
            .most_warm => graindisplay.most_warm,
            .daylight_movie => graindisplay.daylight_movie,
        };
        display_config.night_light = resolved;
    }

    if (preferences.temperature) |value| {
        display_config.night_light.temperature = value;
    }

    if (preferences.enable) |value| {
        display_config.night_light.enabled = value;
    }

    if (preferences.mode) |mode| {
        display_config.mode = mode;
    }

    if (preferences.font_scale) |scale| {
        interface_config.text_scale = scale;
    }
}

test "parse args list handles font scale" {
    const args = [_][]const u8{ "graindisplay", "--font-scale", "1.75", "--enable" };
    const opts = try parse_args_list(std.testing.allocator, &args);
    try std.testing.expect(opts.enable != null and opts.enable.?);
    try std.testing.expect(opts.font_scale != null);
    try std.testing.expectEqual(@as(f64, 1.75), opts.font_scale.?);
}

test "parse args list handles presets and shortcuts" {
    const args = [_][]const u8{ "graindisplay", "--preset", "most-warm", "--font-scale-175" };
    const opts = try parse_args_list(std.testing.allocator, &args);
    try std.testing.expect(opts.preset != null);
    try std.testing.expectEqualStrings("most-warm", opts.preset.?);
    try std.testing.expect(opts.font_scale != null);
    try std.testing.expectEqual(@as(f64, 1.75), opts.font_scale.?);
}

test "preset lookup by name" {
    try std.testing.expect(presetByName("most-warm") != null);
    try std.testing.expect(presetByName("unknown") == null);
}
