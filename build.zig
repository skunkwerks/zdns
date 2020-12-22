const std = @import("std");
const bld = std.build;

fn addDependencies(step: *bld.LibExeObjStep) void {
    step.linkLibC();
    step.linkSystemLibrary("ldns");
}

pub fn build(b: *bld.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const test_cmd = b.addTest("src/zdns.zig");
    addDependencies(test_cmd);

    test_cmd.setTarget(target);
    test_cmd.setBuildMode(mode);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_cmd.step);
}
