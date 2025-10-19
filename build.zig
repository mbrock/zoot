const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zoot", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/demo-styled.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "zoot-demo",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    var exe_check = b.addExecutable(.{
        .name = "zoot-check",
        .root_module = exe_mod,
    });

    const check = b.step("check", "Build without linking");
    check.dependOn(&exe_check.step);

    const run_step = b.step("run", "Run the Zoot demo");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const demo_styled_mod = b.createModule(.{
        .root_source_file = b.path("src/demo-styled.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = mod },
        },
    });

    const demo_styled = b.addExecutable(.{
        .name = "zoot-demo-styled",
        .root_module = demo_styled_mod,
    });

    b.installArtifact(demo_styled);

    const run_styled_step = b.step("run-styled", "Run the styled demo");
    const run_styled_cmd = b.addRunArtifact(demo_styled);
    run_styled_step.dependOn(&run_styled_cmd.step);
    run_styled_cmd.step.dependOn(b.getInstallStep());

    const bench_mod = b.createModule(.{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = mod },
        },
    });

    const bench = b.addExecutable(.{
        .name = "zoot-bench",
        .root_module = bench_mod,
    });

    b.installArtifact(bench);

    const bench_step = b.step("bench", "Run the benchmark");
    const bench_cmd = b.addRunArtifact(bench);
    bench_step.dependOn(&bench_cmd.step);
    bench_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        bench_cmd.addArgs(args);
    }

    const graphviz_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = mod },
        },
    });

    const graphviz_exe = b.addExecutable(.{
        .name = "zoot-graphviz",
        .root_module = graphviz_mod,
        .use_llvm = true,
    });

    b.installArtifact(graphviz_exe);

    const graphviz_step = b.step("graphviz", "Generate graphviz visualization");
    const graphviz_cmd = b.addRunArtifact(graphviz_exe);
    graphviz_step.dependOn(&graphviz_cmd.step);
    graphviz_cmd.step.dependOn(b.getInstallStep());

    const serve_step = b.step("serve", "Start HTTP server for visualization");
    const serve_cmd = b.addSystemCommand(&.{ "python3", "-m", "http.server", "8000" });
    serve_step.dependOn(&serve_cmd.step);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
