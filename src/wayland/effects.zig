const types = @import("../types.zig");
const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;

pub const EffectsClient = struct {
    allocator: std.mem.Allocator,
    display: *wl.Display,
    registry: *wl.Registry,
    manager: ?*zwlr.gamma_control_manager_v1 = null,

    pub fn init(allocator: std.mem.Allocator) !EffectsClient {
        const display = try wl.Display.connect(null);
        errdefer display.disconnect();

        const registry = try display.getRegistry();
        var client = EffectsClient{
            .allocator = allocator,
            .display = display,
            .registry = registry,
            .manager = null,
        };

        registry.setListener(*EffectsClient, registryListener, &client);
        if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

        if (client.manager == null) {
            client.deinit();
            return error.GammaManagerUnavailable;
        }

        return client;
    }

    pub fn deinit(self: *EffectsClient) void {
        if (self.manager) |manager| {
            manager.destroy();
            self.manager = null;
        }
        self.registry.destroy();
        self.display.disconnect();
    }

    pub fn apply(self: *EffectsClient, effects: types.DisplayEffects) !void {
        _ = self;
        _ = effects;
        return error.Unimplemented;
    }

    pub fn reset(self: *EffectsClient) !void {
        _ = self;
        return error.Unimplemented;
    }
};

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, client: *EffectsClient) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, zwlr.gamma_control_manager_v1.interface.name) == .eq) {
                const manager = registry.bind(global.name, zwlr.gamma_control_manager_v1, 1) catch return;
                client.manager = manager;
            }
        },
        .global_remove => |_| {},
    }
}

pub fn describeEffects(allocator: std.mem.Allocator, effects: types.DisplayEffects) ![]const u8 {
    if (effects.monochrome and effects.red_green) {
        return try allocator.dupe(u8, "monochrome + red-green");
    } else if (effects.monochrome) {
        return try allocator.dupe(u8, "monochrome");
    } else if (effects.red_green) {
        return try allocator.dupe(u8, "red-green");
    }
    return try allocator.dupe(u8, "normal");
}
