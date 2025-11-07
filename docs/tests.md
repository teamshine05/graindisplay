# graindisplay test suite

this project now ships a layered test suite to guarantee behaviour for both the
night light controls and the new Wayland text scaling feature.

## running tests

```
zig build test
```

all tests use zig's built-in runner. they rely exclusively on deterministic mock
command runners and do not touch live `gsettings`.

## structure

- **unit tests (pure)** – validate argument parsing (`parse_args_list`) and
  small helpers without any command execution.
- **unit tests (mocked gsettings)** – the `gsettings.Client` is exercised with a
  fake `CommandRunner` that records the commands we would send to GNOME.
- **integration tests (system config)** – apply/read the combined
  `SystemConfig`, ensuring display + interface commands run in the expected
  order.
- **randomized tests** – `interface scaling randomized sequences` generates 16
  pseudo-random scaling factors (0.75x – 2.25x) and asserts that each call emits
  the properly formatted command. this guards against formatting regressions and
  ensures we keep covering more than a single hard-coded value.

## extending the suite

1. model the behaviour with a new test under `src/gsettings.zig` or
   `src/cli.zig`.
2. prefer testing through the public client (`Client`) or argument parser – the
   goal is to exercise interfaces consumers rely on.
3. when adding new command types, extend the mock state helpers so tests remain
   expressive.

## future ideas

- seed-driven, longer randomized runs gated behind an env flag (to keep default
  test times short).
- fuzzing the CLI argument parser with zig's upcoming property-based testing
  helpers.
