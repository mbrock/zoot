const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;
const viz = @import("zoot").PrettyViz;
const dump = @import("zoot").dump;

const Step = union(enum) {
    run: Run,
    wait: u32,
    parallel: []const Step,
};

const Run = struct {
    tool: []const u8,
    args: []const []const u8,
};

const Pipeline = struct {
    name: []const u8,
    enabled: bool,
    retries: ?u8,
    tags: []const []const u8,
    steps: []const Step,
};

pub fn main() !void {
    var gpa = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer: [8192]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    var t = pp.Tree.init(allocator);
    defer t.deinit();

    const pipeline_tags = &.{ "cli", "zig", "pretty" };
    const pipeline_steps = &.{
        Step{
            .run = .{
                .tool = "zig",
                .args = &.{ "build", "-Drelease-safe=true" },
            },
        },
        Step{ .wait = 30 },
        Step{
            .parallel = &.{
                Step{ .run = .{ .tool = "zig", .args = &.{"test"} } },
                Step{
                    .run = .{
                        .tool = "deploy",
                        .args = &.{ "us-west", "blue" },
                    },
                },
            },
        },
    };

    const pipeline = Pipeline{
        .name = "release",
        .enabled = true,
        .retries = null,
        .tags = pipeline_tags,
        .steps = pipeline_steps,
    };

    var time = try std.time.Timer.start();
    const doc = try dump.dump(&t, pipeline);
    const t0 = time.lap();

    try t.heap.work.list.ensureUnusedCapacity(allocator, 1024 * 32);

    var best = try t.best(allocator, pp.F1.init(40), doc, null);
    defer best.deinit(allocator);
    const t1 = time.lap();

    try t.renderWithPath(writer, doc, &best);
    const t2 = time.read();
    try writer.print("\n\n  (measured 2^{d} variants)\n", .{best.bits.bit_length});
    try writer.print("  (dump {D}; maze {D}; emit {D})\n\n", .{ t0, t1, t2 });
    try writer.flush();

    // {
    //     const file = try std.fs.cwd().createFile("graphviz.dot", .{});
    //     defer file.close();
    //     var sink = file.writer(&buffer);
    //     try viz.graphviz(&t, &sink.interface, doc);
    // }

    // {
    //     const file = try std.fs.cwd().createFile("tree.json", .{});
    //     defer file.close();
    //     var sink = file.writer(&buffer);
    //     try viz.toJson(&t, &sink.interface, doc);
    // }
}
