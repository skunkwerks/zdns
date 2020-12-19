const std = @import("std");
const bld = std.build;

fn addDependencies(step: *bld.LibExeObjStep) void {
    step.linkLibC();
    step.linkSystemLibrary("ldns");
}

pub fn compareOutput(b: *bld.Builder, exe: *bld.LibExeObjStep) !*bld.Step {
    const testDir = try std.fs.cwd().openDirZ("test", .{ .iterate = true });
    var it = testDir.iterate();

    const step = b.step("compare-output", "Test - Compare output");

    while (try it.next()) |file| {
        if (std.mem.endsWith(u8, file.name, ".zone")) {
            const run = exe.run();
            run.addArg(try std.mem.concat(b.allocator, u8, &[_][]const u8{ "test/", file.name }));

            const jsonFileName = try std.mem.concat(b.allocator, u8, &[_][]const u8{ file.name[0 .. file.name.len - "zone".len], "json" });
            run.expectStdOutEqual(try testDir.readFileAlloc(b.allocator, jsonFileName, 50 * 1024));
            step.dependOn(&run.step);
        }
    }
    return step;
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

    const exe = b.addExecutable("zone2json", "src/main.zig");

    addDependencies(exe);

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_cmd = b.addTest("src/main.zig");
    addDependencies(test_cmd);

    test_cmd.setTarget(target);
    test_cmd.setBuildMode(mode);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_cmd.step);
    test_step.dependOn(try compareOutput(b, exe));
}
