# graindisplay

warm display configuration for Wayland Night Light

## what is graindisplay?

graindisplay helps you set up a comfortable, warm display that's
easy on your eyes, especially at night. Your display emits blue
light, which can interfere with your body's natural sleep cycle.
By making the display warmer (more orange/red, less blue), we
reduce eye strain and help you wind down naturally. you can also
scale up GNOME's system text (Wayland) to 1.75x for easier reading.

This library works with GNOME's Night Light feature on Ubuntu
24.04 LTS Wayland. It gives you both interactive and non-interactive
ways to configure your display warmth.

## quick start

```zig
const std = @import("std");
const graindisplay = @import("graindisplay");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Apply a preset warm configuration
    try graindisplay.apply_config(allocator, graindisplay.very_warm);

    // Increase GNOME Wayland text scaling to 1.75x
    try graindisplay.apply_interface_config(allocator, graindisplay.text_scale_very_large);
    
    // Or read current settings
    const current = try graindisplay.read_config(allocator);
    std.debug.print("Current temperature: {}K\n", .{current.temperature});

    const ui = try graindisplay.read_interface(allocator);
    std.debug.print("Current text scale: {d:.2}x\n", .{ui.text_scale});
}
```

## command line usage

### interactive mode

```bash
zig build run -- --interactive
# or short form:
zig build run -- -i
```

This will prompt you for each setting, showing your current
values as defaults. Perfect for exploring what works best!

### show current configuration

```bash
zig build run -- --full
# or short form:
zig build run -- -f
```

Shows all current Night Light settings in a readable format.

### apply a preset

```bash
zig build run -- --preset very-warm
# or short form:
zig build run -- -p very-warm
```

**Available presets** (all activate immediately - 24/7):

- `default-warm` - balanced warmth (3000K)
- `extra-warm` - extra warm, like candlelight (2500K)
- `warmer` - warm reading lamp (2800K)
- `very-warm` - warmest possible, like sitting by a fireplace (1700K)
- `moderate-warm` - gentle warmth (4000K)
- `daylight-movie` - subtle warmth for movies during the day (4500K)

**Note:** All presets are configured for 24/7 activation - they'll work immediately regardless of time of day!

### set temperature directly

```bash
# Enable Night Light with custom temperature
zig build run -- --enable --temperature 3200
# or short form:
zig build run -- -t 3200

# Disable Night Light
zig build run -- --disable
```

Temperature range: **1700K** (warmest, like candlelight) to **4700K** (coolest)

### special color modes

```bash
# Monochrome (grayscale) mode
zig build run -- --mode monochrome

# Red-green only mode (no blue channel)
zig build run -- --mode red-green

# Stack modes (monochrome + red-green)
zig build run -- --mode monochrome --mode red-green

# Normal color mode (clears stacked modes)
zig build run -- --mode normal
```

You can pass `--mode` multiple times to combine effects. Use `--mode normal` (or `--mode none`) to clear all effects before applying new ones. The config file accepts comma-separated values, e.g. `mode = monochrome, red-green`. Gamma control requires compositor support; if unavailable, graindisplay logs a warning and skips the effect.

### set text scaling (Wayland GNOME)

```bash
# Set explicit scale (e.g. 1.75x larger text)
zig build run -- --font-scale 1.75

# Shortcut for 1.75x scaling
zig build run -- --font-scale-175

# Combine with presets / temperature changes
zig build run -- --preset very-warm --font-scale-175
```

Text scaling maps to GNOME's `org.gnome.desktop.interface text-scaling-factor`.
Values greater than `1.0` increase the apparent font size; `1.75` gives 75%
larger text across Wayland sessions.

## color temperature guide

Temperature is measured in Kelvins (K). Think of it like this:

- **1700-2500K**: Very warm, like candlelight or a campfire
- **3000-3500K**: Warm, like a cozy reading lamp
- **4000-4700K**: Moderate, slightly warm, still fairly natural

Lower values = warmer (more orange/red)
Higher values = cooler (more blue/white)

## examples

```bash
# Show current configuration
zig build run -- --full
# or short: zig build run -- -f

# Enable Night Light
zig build run -- --enable

# Disable Night Light
zig build run -- --disable

# Apply warm presets (all work 24/7!)
zig build run -- --preset very-warm     # Warmest (1700K)
zig build run -- --preset extra-warm    # Extra warm (2500K)
zig build run -- --preset warmer        # Reading lamp (2800K)
zig build run -- --preset default-warm  # Balanced (3000K)
zig build run -- --preset moderate-warm # Gentle (4000K)
zig build run -- --preset daylight-movie # Subtle for movies (4500K)

# Set custom temperature
zig build run -- --temperature 2800

# Special color modes
zig build run -- --mode monochrome       # Grayscale
zig build run -- --mode red-green        # Red/green only
zig build run -- --mode normal           # Standard color

# Combine presets and modes
zig build run -- --preset very-warm --mode red-green --mode monochrome

# Interactive mode
zig build run -- --interactive
# or short: zig build run -- -i
```

## architecture

graindisplay is decomplected into focused modules:

- `types.zig` - data structures and preset configurations
- `gsettings.zig` - interface to GNOME settings daemon
- `graindisplay.zig` - public API and re-exports
- `cli.zig` - command line interface

each module has one clear responsibility. this makes the code
easier to understand, test, and extend.

## how it works

graindisplay uses GNOME's `gsettings` to configure the Night Light feature
that's built into GNOME on Wayland. It's a simple wrapper that makes it easier
to configure your display warmth.

**Key features:**
- ✅ All presets activate immediately (24/7) - no waiting for sunset!
- ✅ Works with GNOME Wayland's built-in Night Light system
- ✅ Uses proper GNOME settings daemon (`org.gnome.settings-daemon.plugins.color`)
- ✅ Controls GNOME Wayland text scaling (default 1.0 → 1.75x and beyond)
- ✅ Simple, decomplected Zig code that's easy to understand and modify

**The key settings we control:**
- `night-light-enabled` - turn Night Light on or off
- `night-light-temperature` - how warm the colors get (in Kelvins)
- `night-light-schedule-automatic` - use sunset/sunrise timing (disabled in all presets for 24/7 activation)
- `night-light-schedule-from` / `night-light-schedule-to` - manual timing (set to 0.0-24.0 for always-on)
- `text-scaling-factor` - GNOME Wayland text scaling multiplier (1.0 default, 1.75 recommended for easier reading)

## building

```bash
# run tests
zig build test

# build the CLI
zig build

# run the CLI
zig build run -- --help
```

## configuration

We ship a template at `config/graindisplay.example.cfg`. Copy it to
`~/.config/graindisplay/config.cfg` (the directory is ignored by git) and adjust
the values you want the CLI to use by default:

```
mkdir -p ~/.config/graindisplay
cp config/graindisplay.example.cfg ~/.config/graindisplay/config.cfg
```

Supported keys:
- `preset` – one of `default-warm`, `extra-warm`, `warmer`, `very-warm`,
  `moderate-warm`, `daylight-movie`
- `temperature` – Kelvin override (integer)
- `enable` – `true` or `false`
- `mode` – `normal`, `monochrome`, or `red-green`; comma-separated for multiple effects
- `font_scale` – Wayland scaling factor such as `1.75`

Command-line flags always override config values. With the build script forwarding
arguments you can now run:

```
zig build run -- --font-scale-175
zig build run -- --preset very-warm
```

## testing

See `docs/tests.md` for an overview of our unit, integration, and randomized
tests. The suite relies on mocked `gsettings` runners, so it can be run safely on
any machine.

## file structure

```
graindisplay/
├── src/
│   ├── types.zig           # data structures and presets
│   ├── gsettings.zig       # GNOME settings interface
│   ├── graindisplay.zig    # main module
│   └── cli.zig             # command line interface
├── build.zig               # build system
└── readme.md              # this file
```

## grain style

this codebase follows grain style principles:
- **explicit limits**: bounded temperature range (1700-4700K)
- **zero technical debt**: every line crafted to last
- **code that teaches**: comments explain why, not just what
- **decomplected design**: separate concerns, clear boundaries

## why warm displays?

Research shows that blue light exposure in the evening can:
- disrupt your body's natural sleep cycle
- reduce melatonin production (the sleep hormone)
- cause eye strain and headaches

By making your display warmer at night, you're helping your
body prepare for rest naturally. It's a simple change that
can make a real difference in how you feel!

## team

**teamshine05** (Leo ♌ / V. The Hierophant)

the illuminators who teach time, wisdom, and tradition. leo's
solar radiance meets the hierophant's patient teaching. we make
comfort visible, understandable, and beautiful.

## contributing

questions, bug reports, or ideas? reach out:
- instagram: `@risc.love`
- discord: `@kae3g`

we love hearing from people using graindisplay in their nightly workflows.

## license

triple licensed: MIT / Apache 2.0 / CC BY 4.0

choose whichever license suits your needs.

