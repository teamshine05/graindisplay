# 2025-11-06 initial implementation snapshot

## why keep this note

we refactor graindisplay to add system font scaling control and deeper tests. this note preserves what worked in the original version so we can confirm parity.

## cli behaviours (validated manually)

- `zig build run -- --interactive` prompts for `enabled` + `temperature` and applies settings.
- `zig build run -- --full` prints:
  - `Enabled` boolean
  - `Temperature` in kelvin with warmth descriptor
  - schedule fields when manual
- `zig build run -- --preset most-warm` and other presets apply immediately.
- `zig build run -- --temperature 3200` adjusts temperature without interactive mode.
- `zig build run -- --enable/--disable` toggle night light.
- `--mode monochrome` / `--mode red-green` accepted but documented as future work (no Wayland protocol execution yet).

## implementation shortcuts we will replace

- direct `std.process.Child.run` calls inline; no abstraction for command execution.
- `apply_config` ignores allocator parameter; fine but not explicit.
- no unit tests beyond Zig’s default placeholder.
- CLI logic coupled tightly with `graindisplay` module; hard to test parsing without hitting gsettings.
- documentation focused solely on Night Light temperature.

## guaranteed invariants to preserve

- temperature range clamp handled upstream (GNOME rejects out-of-range; we keep same expectations).
- schedules default to 24/7 manual for presets.
- CLI success message: `✅ Configuration applied!`
- interactive path reads existing config before prompting.

## baseline manual test plan

1. run `zig build run -- --full` before/after applying configs – values change.
2. apply `most-warm` preset, confirm GNOME settings show `1700`.
3. interactive mode toggling `enabled` works.

these behaviours must still hold once we refactor with injected command runner and new font scaling feature.


