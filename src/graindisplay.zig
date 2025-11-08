//! graindisplay: warm display configuration for Wayland Night Light
//!
//! What is graindisplay? It's how we set up a comfortable, warm
//! display that's easy on your eyes, especially at night.
//!
//! Your display emits blue light, which can interfere with your
//! body's natural sleep cycle. By making the display warmer
//! (more orange/red, less blue), we reduce eye strain and help
//! you wind down naturally.
//!
//! This library works with GNOME's Night Light feature on
//! Ubuntu 24.04 LTS Wayland. It gives you both interactive
//! and non-interactive ways to configure your display warmth.

const std = @import("std");

pub const types = @import("types.zig");
pub const gsettings = @import("gsettings.zig");

pub const CommandRunner = gsettings.CommandRunner;
pub const Client = gsettings.Client;

pub const NightLightConfig = types.NightLightConfig;
pub const DisplayConfig = types.DisplayConfig;
pub const DisplayEffect = types.DisplayEffect;
pub const DisplayEffects = types.DisplayEffects;
pub const InterfaceConfig = types.InterfaceConfig;
pub const SystemConfig = types.SystemConfig;

pub const default_warm = types.default_warm;
pub const extra_warm = types.extra_warm;
pub const moderate_warm = types.moderate_warm;
pub const warmer = types.warmer;
pub const very_warm = types.very_warm;
pub const daylight_movie = types.daylight_movie;

pub const text_scale_default = types.default_interface;
pub const text_scale_large = types.text_scale_large;
pub const text_scale_extra_large = types.text_scale_extra_large;
pub const text_scale_very_large = types.text_scale_very_large;
pub const text_scale_max = types.text_scale_max;

pub fn systemRunner() CommandRunner {
    return gsettings.systemRunner();
}

pub fn open(allocator: std.mem.Allocator) Client {
    return gsettings.Client.init(allocator, systemRunner());
}

pub fn read_night_light(allocator: std.mem.Allocator) !NightLightConfig {
    var client = open(allocator);
    return client.readNightLight();
}

pub fn read_config(allocator: std.mem.Allocator) !NightLightConfig {
    return read_night_light(allocator);
}

pub fn apply_config(allocator: std.mem.Allocator, config: NightLightConfig) !void {
    var client = open(allocator);
    try client.applyNightLight(config);
}

pub fn apply_display_config(allocator: std.mem.Allocator, config: DisplayConfig) !void {
    var client = open(allocator);
    try client.applyDisplay(config);
}

pub fn read_display(allocator: std.mem.Allocator) !DisplayConfig {
    var client = open(allocator);
    return types.DisplayConfig{
        .night_light = try client.readNightLight(),
    };
}

pub fn read_interface(allocator: std.mem.Allocator) !InterfaceConfig {
    var client = open(allocator);
    return try client.readInterface();
}

pub fn apply_interface_config(allocator: std.mem.Allocator, config: InterfaceConfig) !void {
    var client = open(allocator);
    try client.applyInterface(config);
}

pub fn apply_interface(allocator: std.mem.Allocator, config: InterfaceConfig) !void {
    try apply_interface_config(allocator, config);
}

pub fn read_system(allocator: std.mem.Allocator) !SystemConfig {
    var client = open(allocator);
    return try client.readSystem();
}

pub fn apply_system_config(allocator: std.mem.Allocator, config: SystemConfig) !void {
    var client = open(allocator);
    try client.applySystem(config);
}
