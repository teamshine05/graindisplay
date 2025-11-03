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

// Re-export our modules for external use.
//
// Why re-export? This pattern creates a clean public API.
// Users import "graindisplay" and get everything they need,
// but internally we keep concerns separated into modules.
pub const types = @import("types.zig");
pub const gsettings = @import("gsettings.zig");

// Re-export commonly used types for convenience.
pub const NightLightConfig = types.NightLightConfig;
pub const apply_config = gsettings.apply_config;
pub const read_config = gsettings.read_config;

// Re-export preset configurations.
//
// These are ready-to-use configurations that you can apply
// directly. Each one has a different level of warmth!
pub const default_warm = types.default_warm;
pub const very_warm = types.very_warm;
pub const moderate_warm = types.moderate_warm;
pub const warmer = types.warmer;
pub const most_warm = types.most_warm;
pub const daylight_movie = types.daylight_movie;

// Re-export display configuration types.
pub const DisplayConfig = types.DisplayConfig;
pub const DisplayMode = types.DisplayMode;
pub const apply_display_config = gsettings.apply_display_config;

