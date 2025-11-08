//! types: data structures for display configuration
//!
//! What are we storing here? The settings that control how warm
//! your display gets. Think of it like adjusting a lamp - you
//! can make it warmer (more orange/red) or cooler (more blue/white).
//!
//! GNOME's Night Light uses a temperature value measured in
//! Kelvins. Lower values = warmer light, higher values = cooler light.

const std = @import("std");

// Night Light configuration structure.
//
// This holds all the settings we need to control your display's
// warmth. Every field has a clear purpose - no magic numbers!
pub const NightLightConfig = struct {
    // Is Night Light enabled at all?
    //
    // true = Night Light is active (warm colors shown)
    // false = Night Light is disabled (normal colors)
    enabled: bool = true,

    // Color temperature in Kelvins.
    //
    // Typical range: 1700 (warmest, very orange) to 4700 (cooler, less orange)
    // Default: around 3000-4000K is a good balance
    //
    // Why Kelvins? It's a standard way to measure color temperature.
    // Think of it like this: a candle flame is ~1700K (very warm),
    // while daylight is ~6500K (cool/blue). We want somewhere in between!
    temperature: u32 = 3500,

    // Should the schedule be automatic (sunset to sunrise)?
    //
    // true = automatically turns on at sunset, off at sunrise
    // false = use manual schedule times below
    schedule_automatic: bool = true,

    // Manual schedule start time (24-hour format, e.g. 18.0 = 6:00 PM).
    //
    // Only used when schedule_automatic is false.
    // Range: 0.0 to 24.0 (representing hours past midnight)
    schedule_from: f64 = 18.0, // 6:00 PM

    // Manual schedule end time (24-hour format).
    //
    // Only used when schedule_automatic is false.
    schedule_to: f64 = 7.0, // 7:00 AM
};

// Default warm display configuration.
//
// This is a good starting point - warm enough to reduce eye strain
// at night, but not so warm it distorts colors too much.
//
// Note: Set to 24/7 so it's active immediately when applied.
// You can re-enable automatic schedule later if preferred.
pub const default_warm: NightLightConfig = .{
    .enabled = true,
    .temperature = 3000, // Nice warm orange glow
    .schedule_automatic = false, // Always active when applied
    .schedule_from = 0.0,
    .schedule_to = 24.0,
};

// Extra warm configuration (more orange).
//
// Previously named "very warm" (2500K).
// Note: Set to 24/7 so it's active immediately when applied.
pub const extra_warm: NightLightConfig = .{
    .enabled = true,
    .temperature = 2500, // Very warm, like candlelight
    .schedule_automatic = false, // Always active when applied
    .schedule_from = 0.0,
    .schedule_to = 24.0,
};

// Moderate warm configuration.
//
// A gentle warmth that's noticeable but subtle.
//
// Note: Set to 24/7 so it's active immediately when applied.
pub const moderate_warm: NightLightConfig = .{
    .enabled = true,
    .temperature = 4000, // Slightly warm, still fairly natural
    .schedule_automatic = false, // Always active when applied
    .schedule_from = 0.0,
    .schedule_to = 24.0,
};

// Warmer configuration (more orange than default).
//
// Noticeably warmer for evening use, reduces blue light significantly.
//
// Note: Set to 24/7 so it's active immediately when applied.
pub const warmer: NightLightConfig = .{
    .enabled = true,
    .temperature = 2800, // Warm, like a reading lamp
    .schedule_automatic = false, // Always active when applied
    .schedule_from = 0.0,
    .schedule_to = 24.0,
};

// Very warm configuration (warmest possible).
//
// Maximum warmth - like sitting by a fireplace. Use for late night
// when you want the absolute minimum blue light exposure.
//
// Previously called "most warm" (1700K).
// Note: We disable automatic schedule so it's active immediately when applied.
pub const very_warm: NightLightConfig = .{
    .enabled = true,
    .temperature = 1700, // Warmest possible, like candlelight
    .schedule_automatic = false, // Always active when applied
    .schedule_from = 0.0, // All day
    .schedule_to = 24.0, // All night
};

// Daylight movie mode configuration.
//
// Subtle warmth optimized for watching movies during the day.
// Keeps colors accurate while reducing eye strain.
//
// Note: Already set to manual schedule (24/7) for immediate activation.
pub const daylight_movie: NightLightConfig = .{
    .enabled = true,
    .temperature = 4500, // Very subtle warmth, almost neutral
    .schedule_automatic = false, // Always active when applied
    .schedule_from = 0.0,
    .schedule_to = 24.0,
};

// Display effects for color manipulation.
//
// Multiple effects can be combined; absence of any effect is equivalent to
// "normal" mode.
pub const DisplayEffect = enum {
    monochrome,
    red_green,
};

pub const DisplayEffects = struct {
    monochrome: bool = false,
    red_green: bool = false,

    pub fn isNormal(self: DisplayEffects) bool {
        return !self.monochrome and !self.red_green;
    }

    pub fn enable(self: *DisplayEffects, effect: DisplayEffect) void {
        switch (effect) {
            .monochrome => self.monochrome = true,
            .red_green => self.red_green = true,
        }
    }

    pub fn clear(self: *DisplayEffects) void {
        self.* = DisplayEffects{};
    }
};

// Full display configuration including color effects.
//
// This extends Night Light with additional display effects for
// specialized use cases.
pub const DisplayConfig = struct {
    // Night Light settings (temperature-based warmth)
    night_light: NightLightConfig = default_warm,

    // Color effects selection (monochrome/red-green)
    effects: DisplayEffects = .{},

    // For red-green mode: adjust red channel (0.0-1.0, default 1.0 = max)
    red_intensity: f32 = 1.0,

    // For red-green mode: adjust green channel (0.0-1.0, default 1.0 = max)
    green_intensity: f32 = 1.0,
};

// Interface preferences.
//
// Controls how GNOME renders fonts relative to their base size.
// GNOME uses a scaling multiplier where 1.0 means "default size".
// 1.75 means "increase fonts by 75%".
pub const InterfaceConfig = struct {
    text_scale: f64 = 1.0,
};

pub const default_interface: InterfaceConfig = .{
    .text_scale = 1.0,
};

pub const text_scale_large: InterfaceConfig = .{
    .text_scale = 1.25,
};

pub const text_scale_extra_large: InterfaceConfig = .{
    .text_scale = 1.5,
};

pub const text_scale_very_large: InterfaceConfig = .{
    .text_scale = 1.75,
};

pub const text_scale_max: InterfaceConfig = .{
    .text_scale = 2.0,
};

// Comprehensive system configuration.
//
// Allows us to apply both display (color) and interface (font)
// preferences in one call.
pub const SystemConfig = struct {
    display: DisplayConfig = .{},
    interface: InterfaceConfig = .{},
};
