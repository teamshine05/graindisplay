const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the graindisplay module
    const graindisplay_mod = b.addModule("graindisplay", .{
        .root_source_file = b.path("src/graindisplay.zig"),
    });

    // Create CLI root module
    const cli_root_mod = b.createModule(.{
        .root_source_file = b.path("src/cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_root_mod.addImport("graindisplay", graindisplay_mod);

    // Create CLI executable
    const cli_exe = b.addExecutable(.{
        .name = "graindisplay",
        .root_module = cli_root_mod,
    });

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

    // Create test executable
    const tests = b.addTest(.{
        .root_module = test_root_mod,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run graindisplay tests");
    test_step.dependOn(&run_tests.step);
}
