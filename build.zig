const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const profile_outline = b.option(
        bool,
        "profile-outline",
        "Keep the main evaluator boundaries visible to profilers",
    ) orelse false;
    const build_options = b.addOptions();
    build_options.addOption(bool, "profile_outline", profile_outline);

    const rootpack = b.addModule("zoot", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    rootpack.addOptions("build_options", build_options);

    const mainpack = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });

    const zootprog = b.addExecutable(.{
        .name = "zoot",
        .root_module = mainpack,
        .use_llvm = true,
    });

    const testmod = b.addTest(.{ .root_module = rootpack });

    const zootstep = b.step("run", "Run the zoot suit");
    const teststep = b.step("test", "Run tests");
    const zootexec = b.addRunArtifact(zootprog);
    const testexec = b.addRunArtifact(testmod);

    zootstep.dependOn(&zootexec.step);
    zootexec.step.dependOn(b.getInstallStep());
    teststep.dependOn(&testexec.step);

    b.installArtifact(zootprog);
    b.installArtifact(testmod);
}
