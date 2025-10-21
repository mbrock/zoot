const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const rootpack = b.addModule("zoot", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

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

    // Test fork executable
    const testforkpack = b.createModule(.{
        .root_source_file = b.path("src/test_fork.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });
    const testforkprog = b.addExecutable(.{
        .name = "test_fork",
        .root_module = testforkpack,
        .use_llvm = true,
    });
    const testforkstep = b.step("testfork", "Run simple fork test");
    const testforkexec = b.addRunArtifact(testforkprog);
    testforkstep.dependOn(&testforkexec.step);
    testforkexec.step.dependOn(b.getInstallStep());

    // Benchmark executable
    const benchpack = b.createModule(.{
        .root_source_file = b.path("src/benchmark_pretty.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });

    const benchprog = b.addExecutable(.{
        .name = "benchmark_pretty",
        .root_module = benchpack,
        .use_llvm = true,
    });

    const benchstep = b.step("bench", "Run pretty printer benchmarks");
    const benchexec = b.addRunArtifact(benchprog);
    benchstep.dependOn(&benchexec.step);
    benchexec.step.dependOn(b.getInstallStep());

    // Exploration benchmark
    const explorepack = b.createModule(.{
        .root_source_file = b.path("src/bench_explore.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });

    const exploreprog = b.addExecutable(.{
        .name = "bench_explore",
        .root_module = explorepack,
        .use_llvm = true,
    });

    const explorestep = b.step("explore", "Run exploration benchmarks");
    const exploreexec = b.addRunArtifact(exploreprog);
    explorestep.dependOn(&exploreexec.step);
    exploreexec.step.dependOn(b.getInstallStep());

    // Debug trace
    const tracepack = b.createModule(.{
        .root_source_file = b.path("src/debug_trace.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });

    const traceprog = b.addExecutable(.{
        .name = "debug_trace",
        .root_module = tracepack,
        .use_llvm = true,
    });

    const tracestep = b.step("trace", "Run debug trace");
    const traceexec = b.addRunArtifact(traceprog);
    tracestep.dependOn(&traceexec.step);
    traceexec.step.dependOn(b.getInstallStep());

    // Debug trace verbose
    const verbosepack = b.createModule(.{
        .root_source_file = b.path("src/debug_trace_verbose.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });

    const verboseprog = b.addExecutable(.{
        .name = "debug_trace_verbose",
        .root_module = verbosepack,
        .use_llvm = true,
    });

    const verbosestep = b.step("verbose", "Run verbose debug trace");
    const verboseexec = b.addRunArtifact(verboseprog);
    verbosestep.dependOn(&verboseexec.step);
    verboseexec.step.dependOn(b.getInstallStep());

    // Test width40
    const testwidth40pack = b.createModule(.{
        .root_source_file = b.path("src/test_width40.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });
    const testwidth40prog = b.addExecutable(.{
        .name = "test_width40",
        .root_module = testwidth40pack,
        .use_llvm = true,
    });
    const testwidth40step = b.step("width40", "Test width=40 layout");
    const testwidth40exec = b.addRunArtifact(testwidth40prog);
    testwidth40step.dependOn(&testwidth40exec.step);
    testwidth40exec.step.dependOn(b.getInstallStep());

    b.installArtifact(zootprog);
    b.installArtifact(testmod);
    b.installArtifact(benchprog);
    b.installArtifact(exploreprog);
    b.installArtifact(traceprog);
    b.installArtifact(verboseprog);
    b.installArtifact(testwidth40prog);
}
