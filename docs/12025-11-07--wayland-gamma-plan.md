# 12025-11-07 wayland gamma control plan

## objective
implement real colour effects (monochrome, red-green, combinations) by talking directly to the compositor via wayland gamma control protocols. replace placeholder comments in `gsettings.Client.applyDisplay` with a working pipeline.

## current gaps
- `gsettings` only toggles night light temperature; no per-channel control.
- cli supports `--mode` stacking, but nothing happens visually.
- docs/tests describe modes as future work.

## approach
1. **dependency:** pull in a wayland binding (`zig-wayland`) and generate protocol stubs for `wlr-gamma-control` (and later the mutter colour manager). maintain this in `build.zig`.
2. **module:** add `src/wayland/effects.zig` to manage the wayland connection, registry, outputs, and gamma control objects. provide an `EffectsClient` with `init`, `apply(effects)`, `reset()`.
3. **lut generation:** implement helpers that create 16-bit per-channel arrays for monochrome and red/green, respecting `DisplayConfig.red_intensity`/`green_intensity`. store reusable buffers sized to compositor gamma size.
4. **integration:** lazy-initialise a global effects client in `gsettings.Client`. when `DisplayEffects` is non-empty, upload LUTs to all known outputs; on clear, call reset. ensure fallback warning when gamma control is unavailable.
5. **configuration:** recognise `mode = normal` or `none` (already handled) and propagate effects to the new module.
6. **documentation/tests:**
   - update README and config template with compositor requirements.
   - unit test LUT builders (pure zig).
   - add manual test instructions: run under sway/river with gamma control, toggle modes, observe change.
7. **future:** consider GNOME’s colour-management protocol for Mutter once baseline is stable.

## next steps
- wire zig-wayland dependency + protocol generation.
- scaffold `EffectsClient` (connection + registry).
- implement monochrome LUT, integrate with `applyDisplay`.
- add red/green LUT and intensity controls.
- update docs/tests and share manual verification notes.
