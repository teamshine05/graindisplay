//! gsettings: interface to GNOME settings daemon
//!
//! How do we actually change the display settings? GNOME stores
//! them in something called "gsettings" - a system for managing
//! application and desktop preferences.
//!
//! We use the `gsettings` command-line tool to read and write
//! these values. It's safe, it's standard, and it works reliably
//! on Ubuntu 24.04 LTS with GNOME Wayland.

const std = @import("std");
const types = @import("types.zig");

const COLOR_SCHEMA = "org.gnome.settings-daemon.plugins.color";
const INTERFACE_SCHEMA = "org.gnome.desktop.interface";

pub const CommandRunner = struct {
    runFn: *const fn (
        allocator: std.mem.Allocator,
        args: []const []const u8,
    ) anyerror![]u8,

    pub fn run(self: CommandRunner, allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
        return self.runFn(allocator, args);
    }
};

fn systemRun(
    allocator: std.mem.Allocator,
    args: []const []const u8,
) ![]u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
        .max_output_bytes = 2048,
    });

    switch (result.term) {
        .Exited => |code| {
            if (code != 0) return error.GSettingsFailed;
        },
        else => return error.GSettingsFailed,
    }

    return result.stdout;
}

pub fn systemRunner() CommandRunner {
    return CommandRunner{
        .runFn = systemRun,
    };
}

pub const Client = struct {
    allocator: std.mem.Allocator,
    runner: CommandRunner,

    pub fn init(allocator: std.mem.Allocator, runner: CommandRunner) Client {
        return Client{
            .allocator = allocator,
            .runner = runner,
        };
    }

    fn run(self: *Client, args: []const []const u8) ![]u8 {
        var buffer: [8][]const u8 = undefined;
        const total = args.len + 1;
        if (total > buffer.len) return error.ArgumentOverflow;
        buffer[0] = "gsettings";
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            buffer[i + 1] = args[i];
        }
        return try self.runner.run(self.allocator, buffer[0..total]);
    }

    fn runWrite(self: *Client, args: []const []const u8) !void {
        const output = try self.run(args);
        if (output.len != 0) {
            self.allocator.free(output);
        }
    }

    fn readBool(self: *Client, schema: []const u8, key: []const u8) !bool {
        const output = try self.run(&[_][]const u8{ "get", schema, key });
        defer self.allocator.free(output);

        const trimmed = std.mem.trim(u8, output, &std.ascii.whitespace);
        return std.mem.eql(u8, trimmed, "true");
    }

    fn readU32(self: *Client, schema: []const u8, key: []const u8) !u32 {
        const output = try self.run(&[_][]const u8{ "get", schema, key });
        defer self.allocator.free(output);

        var trimmed = std.mem.trim(u8, output, &std.ascii.whitespace);
        if (std.mem.indexOf(u8, trimmed, " ")) |idx| {
            trimmed = trimmed[idx + 1 ..];
            trimmed = std.mem.trim(u8, trimmed, &std.ascii.whitespace);
        }
        if (trimmed.len == 0) return error.InvalidFormat;
        return try std.fmt.parseInt(u32, trimmed, 10);
    }

    fn readF64(self: *Client, schema: []const u8, key: []const u8) !f64 {
        const output = try self.run(&[_][]const u8{ "get", schema, key });
        defer self.allocator.free(output);

        var trimmed = std.mem.trim(u8, output, &std.ascii.whitespace);
        if (std.mem.indexOf(u8, trimmed, " ")) |idx| {
            trimmed = trimmed[idx + 1 ..];
            trimmed = std.mem.trim(u8, trimmed, &std.ascii.whitespace);
        }
        if (trimmed.len == 0) return error.InvalidFormat;
        return try std.fmt.parseFloat(f64, trimmed);
    }

    fn writeBool(self: *Client, schema: []const u8, key: []const u8, value: bool) !void {
        const val = if (value) "true" else "false";
        try self.runWrite(&[_][]const u8{ "set", schema, key, val });
    }

    fn writeU32(self: *Client, schema: []const u8, key: []const u8, value: u32) !void {
        const text = try std.fmt.allocPrint(self.allocator, "{}", .{value});
        defer self.allocator.free(text);
        try self.runWrite(&[_][]const u8{ "set", schema, key, text });
    }

    fn writeF64(self: *Client, schema: []const u8, key: []const u8, value: f64) !void {
        const text = try std.fmt.allocPrint(self.allocator, "{d}", .{value});
        defer self.allocator.free(text);
        try self.runWrite(&[_][]const u8{ "set", schema, key, text });
    }

    pub fn readNightLight(self: *Client) !types.NightLightConfig {
        return types.NightLightConfig{
            .enabled = try self.readBool(COLOR_SCHEMA, "night-light-enabled"),
            .temperature = try self.readU32(COLOR_SCHEMA, "night-light-temperature"),
            .schedule_automatic = try self.readBool(COLOR_SCHEMA, "night-light-schedule-automatic"),
            .schedule_from = try self.readF64(COLOR_SCHEMA, "night-light-schedule-from"),
            .schedule_to = try self.readF64(COLOR_SCHEMA, "night-light-schedule-to"),
        };
    }

    pub fn applyNightLight(self: *Client, config: types.NightLightConfig) !void {
        try self.writeBool(COLOR_SCHEMA, "night-light-enabled", config.enabled);
        try self.writeU32(COLOR_SCHEMA, "night-light-temperature", config.temperature);
        try self.writeBool(COLOR_SCHEMA, "night-light-schedule-automatic", config.schedule_automatic);

        if (!config.schedule_automatic) {
            try self.writeF64(COLOR_SCHEMA, "night-light-schedule-from", config.schedule_from);
            try self.writeF64(COLOR_SCHEMA, "night-light-schedule-to", config.schedule_to);
        }
    }

    pub fn applyDisplay(self: *Client, config: types.DisplayConfig) !void {
        try self.applyNightLight(config.night_light);

        switch (config.mode) {
            .normal => {},
            .monochrome => {},
            .red_green => {},
        }
    }

    pub fn readInterface(self: *Client) !types.InterfaceConfig {
        return types.InterfaceConfig{
            .text_scale = try self.readF64(INTERFACE_SCHEMA, "text-scaling-factor"),
        };
    }

    pub fn applyInterface(self: *Client, config: types.InterfaceConfig) !void {
        try self.writeF64(INTERFACE_SCHEMA, "text-scaling-factor", config.text_scale);
    }

    pub fn readSystem(self: *Client) !types.SystemConfig {
        return types.SystemConfig{
            .display = types.DisplayConfig{
                .night_light = try self.readNightLight(),
            },
            .interface = try self.readInterface(),
        };
    }

    pub fn applySystem(self: *Client, config: types.SystemConfig) !void {
        try self.applyDisplay(config.display);
        try self.applyInterface(config.interface);
    }
};

test "read night light config" {
    const Step = struct {
        expected: []const []const u8,
        response: []const u8,
    };
    const steps = [_]Step{
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-enabled" }, .response = "true" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-temperature" }, .response = "uint32 3000" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-schedule-automatic" }, .response = "false" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-schedule-from" }, .response = "double 0.0" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-schedule-to" }, .response = "double 24.0" },
    };
    const MockState = struct {
        steps: []const Step,
        index: usize = 0,
    };
    var state = MockState{ .steps = &steps };

    const Mock = struct {
        var state_ptr: *MockState = undefined;

        fn run(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
            const Self = @This();
            const st = Self.state_ptr;
            if (st.index >= st.steps.len) return error.UnexpectedCommand;
            const step = st.steps[st.index];
            st.index += 1;
            try std.testing.expectEqual(step.expected.len, args.len);
            var i: usize = 0;
            while (i < args.len) : (i += 1) {
                try std.testing.expectEqualStrings(step.expected[i], args[i]);
            }
            return allocator.dupe(u8, step.response);
        }
    };
    Mock.state_ptr = &state;

    const runner = CommandRunner{ .runFn = Mock.run };

    var client = Client.init(std.testing.allocator, runner);
    const config = try client.readNightLight();
    try std.testing.expect(config.enabled);
    try std.testing.expectEqual(@as(u32, 3000), config.temperature);
    try std.testing.expect(!config.schedule_automatic);
    try std.testing.expectEqual(@as(f64, 0.0), config.schedule_from);
    try std.testing.expectEqual(@as(f64, 24.0), config.schedule_to);
    try std.testing.expectEqual(@as(usize, steps.len), state.index);
}

test "apply night light config writes commands" {
    const Step = struct {
        expected: []const []const u8,
    };
    const steps = [_]Step{
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-enabled", "true" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-temperature", "1700" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-schedule-automatic", "false" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-schedule-from", "0" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-schedule-to", "24" } },
    };
    const MockState = struct {
        steps: []const Step,
        index: usize = 0,
    };
    var state = MockState{ .steps = &steps };

    const Mock = struct {
        var state_ptr: *MockState = undefined;

        fn run(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
            const Self = @This();
            const st = Self.state_ptr;
            if (st.index >= st.steps.len) return error.UnexpectedCommand;
            const step = st.steps[st.index];
            st.index += 1;
            try std.testing.expectEqual(step.expected.len, args.len);
            var i: usize = 0;
            while (i < args.len) : (i += 1) {
                try std.testing.expectEqualStrings(step.expected[i], args[i]);
            }
            return allocator.dupe(u8, "");
        }
    };
    Mock.state_ptr = &state;

    const runner = CommandRunner{ .runFn = Mock.run };

    var client = Client.init(std.testing.allocator, runner);
    const config = types.NightLightConfig{
        .enabled = true,
        .temperature = 1700,
        .schedule_automatic = false,
        .schedule_from = 0.0,
        .schedule_to = 24.0,
    };
    try client.applyNightLight(config);
    try std.testing.expectEqual(@as(usize, steps.len), state.index);
}

test "interface scaling round-trip" {
    const Step = struct {
        expected: []const []const u8,
        response: []const u8,
    };
    const steps = [_]Step{
        .{ .expected = &[_][]const u8{ "gsettings", "get", INTERFACE_SCHEMA, "text-scaling-factor" }, .response = "double 1.0" },
        .{ .expected = &[_][]const u8{ "gsettings", "set", INTERFACE_SCHEMA, "text-scaling-factor", "1.75" }, .response = "" },
    };
    const MockState = struct {
        steps: []const Step,
        index: usize = 0,
    };
    var state = MockState{ .steps = &steps };

    const Mock = struct {
        var state_ptr: *MockState = undefined;

        fn run(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
            const Self = @This();
            const st = Self.state_ptr;
            if (st.index >= st.steps.len) return error.UnexpectedCommand;
            const step = st.steps[st.index];
            st.index += 1;
            try std.testing.expectEqual(step.expected.len, args.len);
            var i: usize = 0;
            while (i < args.len) : (i += 1) {
                try std.testing.expectEqualStrings(step.expected[i], args[i]);
            }
            return allocator.dupe(u8, step.response);
        }
    };
    Mock.state_ptr = &state;

    const runner = CommandRunner{ .runFn = Mock.run };

    var client = Client.init(std.testing.allocator, runner);
    const current = try client.readInterface();
    try std.testing.expectEqual(@as(f64, 1.0), current.text_scale);
    try client.applyInterface(.{ .text_scale = 1.75 });
    try std.testing.expectEqual(@as(usize, steps.len), state.index);
}

test "apply system config writes display and interface commands" {
    const Step = struct {
        expected: []const []const u8,
    };
    const steps = [_]Step{
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-enabled", "true" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-temperature", "1700" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-schedule-automatic", "false" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-schedule-from", "0" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", COLOR_SCHEMA, "night-light-schedule-to", "24" } },
        .{ .expected = &[_][]const u8{ "gsettings", "set", INTERFACE_SCHEMA, "text-scaling-factor", "1.75" } },
    };
    const MockState = struct {
        steps: []const Step,
        index: usize = 0,
    };
    var state = MockState{ .steps = &steps };

    const Mock = struct {
        var state_ptr: *MockState = undefined;

        fn run(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
            const Self = @This();
            const st = Self.state_ptr;
            if (st.index >= st.steps.len) return error.UnexpectedCommand;
            const step = st.steps[st.index];
            st.index += 1;
            try std.testing.expectEqual(step.expected.len, args.len);
            var i: usize = 0;
            while (i < args.len) : (i += 1) {
                try std.testing.expectEqualStrings(step.expected[i], args[i]);
            }
            return allocator.dupe(u8, "");
        }
    };
    Mock.state_ptr = &state;

    const runner = CommandRunner{ .runFn = Mock.run };

    var client = Client.init(std.testing.allocator, runner);
    const system = types.SystemConfig{
        .display = .{
            .night_light = .{
                .enabled = true,
                .temperature = 1700,
                .schedule_automatic = false,
                .schedule_from = 0.0,
                .schedule_to = 24.0,
            },
        },
        .interface = .{ .text_scale = 1.75 },
    };
    try client.applySystem(system);
    try std.testing.expectEqual(@as(usize, steps.len), state.index);
}

test "read system config combines night light and interface" {
    const Step = struct {
        expected: []const []const u8,
        response: []const u8,
    };
    const steps = [_]Step{
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-enabled" }, .response = "true" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-temperature" }, .response = "uint32 2800" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-schedule-automatic" }, .response = "true" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-schedule-from" }, .response = "double 18.0" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", COLOR_SCHEMA, "night-light-schedule-to" }, .response = "double 7.0" },
        .{ .expected = &[_][]const u8{ "gsettings", "get", INTERFACE_SCHEMA, "text-scaling-factor" }, .response = "double 1.25" },
    };
    const MockState = struct {
        steps: []const Step,
        index: usize = 0,
    };
    var state = MockState{ .steps = &steps };

    const Mock = struct {
        var state_ptr: *MockState = undefined;

        fn run(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
            const Self = @This();
            const st = Self.state_ptr;
            if (st.index >= st.steps.len) return error.UnexpectedCommand;
            const step = st.steps[st.index];
            st.index += 1;
            try std.testing.expectEqual(step.expected.len, args.len);
            var i: usize = 0;
            while (i < args.len) : (i += 1) {
                try std.testing.expectEqualStrings(step.expected[i], args[i]);
            }
            return allocator.dupe(u8, step.response);
        }
    };
    Mock.state_ptr = &state;

    const runner = CommandRunner{ .runFn = Mock.run };

    var client = Client.init(std.testing.allocator, runner);
    const system = try client.readSystem();
    try std.testing.expect(system.display.night_light.enabled);
    try std.testing.expectEqual(@as(u32, 2800), system.display.night_light.temperature);
    try std.testing.expect(system.display.night_light.schedule_automatic);
    try std.testing.expectEqual(@as(f64, 18.0), system.display.night_light.schedule_from);
    try std.testing.expectEqual(@as(f64, 7.0), system.display.night_light.schedule_to);
    try std.testing.expectEqual(@as(f64, 1.25), system.interface.text_scale);
    try std.testing.expectEqual(@as(usize, steps.len), state.index);
}

test "interface scaling randomized sequences" {
    const RecordingState = struct {
        buffer: std.ArrayList([]const u8),
    };

    var state = RecordingState{ .buffer = std.ArrayList([]const u8).init(std.testing.allocator) };
    defer {
        for (state.buffer.items) |item| {
            std.testing.allocator.free(item);
        }
        state.buffer.deinit();
    }

    const Mock = struct {
        var state_ptr: *RecordingState = undefined;

        fn run(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
            const Self = @This();
            const st = Self.state_ptr;
            for (st.buffer.items) |item| {
                allocator.free(item);
            }
            st.buffer.clearRetainingCapacity();

            var i: usize = 0;
            while (i < args.len) : (i += 1) {
                const copy = try allocator.dupe(u8, args[i]);
                try st.buffer.append(copy);
            }
            return allocator.dupe(u8, "");
        }
    };
    Mock.state_ptr = &state;

    const runner = CommandRunner{ .runFn = Mock.run };

    var client = Client.init(std.testing.allocator, runner);
    var prng = std.rand.DefaultPrng.init(0x1234abcd);
    const random = prng.random();

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const scale = 0.75 + random.float(f64) * 1.50; // range 0.75 - 2.25
        try client.applyInterface(.{ .text_scale = scale });
        try std.testing.expectEqual(@as(usize, 5), state.buffer.items.len);
        try std.testing.expectEqualStrings("gsettings", state.buffer.items[0]);
        try std.testing.expectEqualStrings("set", state.buffer.items[1]);
        try std.testing.expectEqualStrings(INTERFACE_SCHEMA, state.buffer.items[2]);
        try std.testing.expectEqualStrings("text-scaling-factor", state.buffer.items[3]);

        const value_str = state.buffer.items[4];
        const parsed = try std.fmt.parseFloat(f64, value_str);
        try std.testing.expectApproxEqAbs(scale, parsed, 1e-9);
    }
}
