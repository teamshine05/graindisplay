const std = @import("std");
const Scanner = @import("wayland").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{});
    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addCustomProtocol(b.path("protocols/wlr-gamma-control-unstable-v1.xml"));
    scanner.generate("wl_compositor", 5);
    scanner.generate("wl_output", 4);
    scanner.generate("zwlr_gamma_control_manager_v1", 1);

    const wayland_mod = b.createModule(.{
        .root_source_file = scanner.result,
        .target = target,
        .optimize = optimize,
    });

    // Create the graindisplay module
    const graindisplay_mod = b.addModule("graindisplay", .{
        .root_source_file = b.path("src/graindisplay.zig"),
    });
    graindisplay_mod.addImport("wayland", wayland_mod);

    // Create CLI root module
    const cli_root_mod = b.createModule(.{
        .root_source_file = b.path("src/cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_root_mod.addImport("graindisplay", graindisplay_mod);
    cli_root_mod.addImport("wayland", wayland_mod);

    // Create CLI executable
    const cli_exe = b.addExecutable(.{
        .name = "graindisplay",
        .root_module = cli_root_mod,
    });
    cli_exe.linkLibC();
    cli_exe.linkSystemLibrary("wayland-client");

    b.installArtifact(cli_exe);

    const run_cli = b.addRunArtifact(cli_exe);
    run_cli.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cli.addArgs(args);
    }

    const run_step = b.step("run", "Run the CLI");
    run_step.dependOn(&run_cli.step);

    // Create test root module
    const test_root_mod = b.createModule(.{
        .root_source_file = b.path("src/graindisplay.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_root_mod.addImport("wayland", wayland_mod);

    // Create test executable
    const tests = b.addTest(.{
        .root_module = test_root_mod,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run graindisplay tests");
    test_step.dependOn(&run_tests.step);
}
