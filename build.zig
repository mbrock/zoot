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

    const recursive_stress_pack = b.createModule(.{
        .root_source_file = b.path("examples/recursive_stress.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zoot", .module = rootpack },
        },
    });
    const recursive_stress_program = b.addExecutable(.{
        .name = "zoot-recursive-stress",
        .root_module = recursive_stress_pack,
        .use_llvm = true,
    });
    const recursive_stress_step = b.step(
        "stress-recursive",
        "Stress the recursive evaluator with a large JSON array",
    );
    const recursive_stress_exec = b.addRunArtifact(recursive_stress_program);
    if (b.args) |args| recursive_stress_exec.addArgs(args);
    recursive_stress_step.dependOn(&recursive_stress_exec.step);

    const testmod = b.addTest(.{ .root_module = rootpack });

    const zootstep = b.step("run", "Run the zoot suit");
    const teststep = b.step("test", "Run tests");
    const zootexec = b.addRunArtifact(zootprog);
    const testexec = b.addRunArtifact(testmod);

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const wasm_rootpack = b.addModule("zoot-wasm-lib", .{
        .root_source_file = b.path("src/root.zig"),
        .target = wasm_target,
    });
    wasm_rootpack.addOptions("build_options", build_options);
    const wasmpack = b.createModule(.{
        .root_source_file = b.path("src/wasm.zig"),
        .target = wasm_target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zoot", .module = wasm_rootpack }},
    });
    const wasm = b.addExecutable(.{
        .name = "zoot-cbor",
        .root_module = wasmpack,
        .use_llvm = true,
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    wasm.export_memory = true;
    const install_wasm = b.addInstallArtifact(wasm, .{});
    b.getInstallStep().dependOn(&install_wasm.step);
    const wasm_step = b.step("wasm", "Build the CBOR-to-JSON WebAssembly module");
    wasm_step.dependOn(&install_wasm.step);

    const typstpack = b.createModule(.{
        .root_source_file = b.path("src/typst_wasm.zig"),
        .target = wasm_target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zoot", .module = wasm_rootpack }},
    });
    const typst_plugin = b.addExecutable(.{
        .name = "zoot-typst",
        .root_module = typstpack,
        .use_llvm = true,
    });
    typst_plugin.entry = .disabled;
    typst_plugin.rdynamic = true;
    typst_plugin.export_memory = true;
    const install_typst_plugin = b.addInstallArtifact(typst_plugin, .{});
    b.getInstallStep().dependOn(&install_typst_plugin.step);
    const typst_step = b.step("typst-plugin", "Build the Typst WebAssembly plugin");
    typst_step.dependOn(&install_typst_plugin.step);

    zootstep.dependOn(&zootexec.step);
    zootexec.step.dependOn(b.getInstallStep());
    teststep.dependOn(&testexec.step);

    b.installArtifact(zootprog);
    b.installArtifact(testmod);
}
