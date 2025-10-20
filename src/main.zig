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
    var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
                .args = &.{
                    "build",
                    "-Drelease-safe=true",
                    "build",
                    "-Drelease-safe=true",
                    "build",
                    "-Drelease-safe=true",
                    "build",
                    "-Drelease-safe=true",
                },
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

    const pipelines = try allocator.alloc(Pipeline, 1);
    for (pipelines, 0..) |*p, i| {
        p.* = .{
            .name = try std.fmt.allocPrint(allocator, "pipeline-{d}", .{i}),
            .enabled = i % 2 == 0,
            .retries = if (i % 5 == 0) null else @intCast(i % 5),
            .tags = pipeline_tags,
            .steps = pipeline_steps,
        };
    }

    var time = try std.time.Timer.start();
    const doc = try dump.dump(&t, pipelines);
    const cost_factory = pp.F2.init(80);

    const t0 = time.lap();
    const best = try t.pick(allocator, cost_factory, doc);
    const t1 = time.lap();

    const measure = best.measure;
    const rank = measure.gist.rank;

    try writer.print(
        "  rank: overflow={d} height={d} tainted={}\n",
        .{ rank.o, rank.h, cost_factory.icky(rank) },
    );
    try writer.print(
        "  layouts: completions={d} frontier={d} tainted_kept={} queue_peak={d}\n",
        .{ best.completions, best.frontier_non_tainted, best.tainted_kept, best.queue_peak },
    );
    try writer.print(
        "  memo: hits={d} misses={d} entries={d}\n\n",
        .{ best.memo_hits, best.memo_misses, best.memo_entries },
    );

    try t.emit(writer, measure.node);
    const t3 = time.read();
    try writer.print(
        "  (dump {D}; best {D}; emit {D})\n\n",
        .{ t0, t1, t3 },
    );
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
