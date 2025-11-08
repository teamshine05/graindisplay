const std = @import("std");
const types = @import("../types.zig");

pub const EffectsClient = struct {
    // future: hold wayland connection + gamma objects

    pub fn init(allocator: std.mem.Allocator) !EffectsClient {
        const display_present = std.process.hasEnvVar(allocator, "WAYLAND_DISPLAY") catch false;
        if (!display_present) {
            return error.DisplayNotRunning;
        }
        // TODO: connect to wayland compositor and bind gamma-control
        return EffectsClient{};
    }

    pub fn apply(self: *EffectsClient, effects: types.DisplayEffects) !void {
        _ = self;
        _ = effects;
        // TODO: upload LUTs via wayland gamma protocol
        return error.Unsupported;
    }

    pub fn reset(self: *EffectsClient) !void {
        _ = self;
        // TODO: restore compositor default gamma
        return error.Unsupported;
    }
};

pub fn describeEffects(
    allocator: std.mem.Allocator,
    effects: types.DisplayEffects,
) ![]const u8 {
    if (effects.monochrome and effects.red_green) {
        return try allocator.dupe(u8, "monochrome + red-green");
    } else if (effects.monochrome) {
        return try allocator.dupe(u8, "monochrome");
    } else if (effects.red_green) {
        return try allocator.dupe(u8, "red-green");
    }
    return try allocator.dupe(u8, "normal");
}
