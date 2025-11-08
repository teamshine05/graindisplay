const std = @import("std");
const types = @import("types.zig");

pub const Preference = struct {
    preset: ?Preset = null,
    temperature: ?u32 = null,
    enable: ?bool = null,
    effects: ?types.DisplayEffects = null,
    clear_effects: bool = false,
    font_scale: ?f64 = null,

    pub const Preset = enum {
        default_warm,
        extra_warm,
        moderate_warm,
        warmer,
        very_warm,
        daylight_movie,
    };
};

pub fn loadDefault(allocator: std.mem.Allocator) !?Preference {
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch return null;
    defer allocator.free(home);

    const path = try std.fs.path.join(allocator, &[_][]const u8{ home, ".config", "graindisplay", "config.cfg" });
    defer allocator.free(path);

    return try loadFile(allocator, path);
}

pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) !?Preference {
    var file = std.fs.cwd().openFile(path, .{}) catch |err| {
        switch (err) {
            error.FileNotFound => return null,
            else => return err,
        }
    };
    defer file.close();

    const stat = try file.stat();
    if (stat.size == 0) return Preference{};

    const data = try file.readToEndAlloc(allocator, stat.size + 1);
    defer allocator.free(data);

    return try parseBuffer(data);
}

fn parseBuffer(buffer: []const u8) !?Preference {
    var prefs = Preference{};
    var it = std.mem.splitScalar(u8, buffer, '\n');
    while (it.next()) |line| {
        const trimmed = trim(line);
        if (trimmed.len == 0) continue;
        if (trimmed[0] == '#') continue;

        const eq_index = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
        const key = trim(trimmed[0..eq_index]);
        const value = trim(trimmed[eq_index + 1 ..]);
        if (value.len == 0) continue;

        if (std.mem.eql(u8, key, "preset")) {
            prefs.preset = parsePreset(value) orelse continue;
        } else if (std.mem.eql(u8, key, "temperature")) {
            prefs.temperature = std.fmt.parseInt(u32, value, 10) catch continue;
        } else if (std.mem.eql(u8, key, "enable")) {
            prefs.enable = parseBool(value) orelse continue;
        } else if (std.mem.eql(u8, key, "mode")) {
            if (std.ascii.eqlIgnoreCase(value, "normal") or std.ascii.eqlIgnoreCase(value, "none")) {
                prefs.clear_effects = true;
            } else {
                var effects = prefs.effects orelse types.DisplayEffects{};
                var it_modes = std.mem.tokenizeAny(u8, value, ", ");
                var any = false;
                while (it_modes.next()) |token| {
                    const trimmed_token = trim(token);
                    if (trimmed_token.len == 0) continue;
                    if (std.ascii.eqlIgnoreCase(trimmed_token, "normal") or std.ascii.eqlIgnoreCase(trimmed_token, "none")) {
                        prefs.clear_effects = true;
                        continue;
                    }
                    if (parseEffect(trimmed_token)) |effect| {
                        effects.enable(effect);
                        any = true;
                    }
                }
                if (any) prefs.effects = effects;
            }
        } else if (std.mem.eql(u8, key, "font_scale")) {
            prefs.font_scale = std.fmt.parseFloat(f64, value) catch continue;
        } else {
            // Unknown keys are ignored to keep config forward compatible.
            continue;
        }
    }

    return prefs;
}

fn trim(input: []const u8) []const u8 {
    return std.mem.trim(u8, input, &std.ascii.whitespace);
}

fn parseBool(value: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(value, "true")) return true;
    if (std.ascii.eqlIgnoreCase(value, "false")) return false;
    return null;
}

fn parsePreset(value: []const u8) ?Preference.Preset {
    if (std.mem.eql(u8, value, "default-warm")) return .default_warm;
    if (std.mem.eql(u8, value, "extra-warm")) return .extra_warm;
    if (std.mem.eql(u8, value, "moderate-warm")) return .moderate_warm;
    if (std.mem.eql(u8, value, "warmer")) return .warmer;
    if (std.mem.eql(u8, value, "very-warm")) return .very_warm;
    if (std.mem.eql(u8, value, "daylight-movie")) return .daylight_movie;
    return null;
}

fn parseEffect(value: []const u8) ?types.DisplayEffect {
    if (std.mem.eql(u8, value, "monochrome")) return .monochrome;
    if (std.mem.eql(u8, value, "red-green")) return .red_green;
    return null;
}

pub fn parseFromBytes(buffer: []const u8) !Preference {
    return (try parseBuffer(buffer)) orelse Preference{};
}

test "parse config buffer" {
    const config_text =
        \\# comment
        \\preset = very-warm
        \\font_scale = 1.75
        \\enable = false
        \\mode = monochrome, red-green
        \\temperature = 3200
    ;

    const prefs = try parseFromBytes(config_text);
    try std.testing.expectEqual(@as(?Preference.Preset, .very_warm), prefs.preset);
    try std.testing.expectEqual(@as(?f64, 1.75), prefs.font_scale);
    try std.testing.expectEqual(@as(?bool, false), prefs.enable);
    try std.testing.expect(prefs.effects != null);
    if (prefs.effects) |effects| {
        try std.testing.expect(effects.monochrome);
        try std.testing.expect(effects.red_green);
    }
    try std.testing.expectEqual(@as(?u32, 3200), prefs.temperature);
}

test "parse ignores unknown lines" {
    const config_text =
        \\unknown = value
        \\font_scale = 1.25
        \\mode = none
    ;

    const prefs = try parseFromBytes(config_text);
    try std.testing.expectEqual(@as(?f64, 1.25), prefs.font_scale);
    try std.testing.expect(prefs.clear_effects);
}
