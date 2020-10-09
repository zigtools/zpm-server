const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const http = std.build.Pkg{
        .name = "http",
        .path = "libs/apple_pie/src/apple_pie.zig",
        .dependencies = &[_]std.build.Pkg{},
    };

    const packages_dir = b.option([]const u8, "packages-dir", "Directory where all package json files are stored") orelse
        "test/packages";
    const tags_dir = b.option([]const u8, "tags-dir", "Directory where all tag json files are stored") orelse
        "test/tags";

    const exe = b.addExecutable("zpm-server", "src/main.zig");
    exe.addBuildOption([]const u8, "packages_dir", packages_dir);
    exe.addBuildOption([]const u8, "tags_dir", tags_dir);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackage(http);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
