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

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();
    const gc_tide = if (args.next()) |arg|
        try std.fmt.parseInt(usize, arg, 10)
    else
        (pp.PickOptions{}).gc_tide;
    var computation_width: ?u16 = null;
    var trace_gc = false;
    var trace_memo = false;
    var memoize = true;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "trace")) {
            trace_gc = true;
        } else if (std.mem.eql(u8, arg, "memodump")) {
            trace_memo = true;
        } else if (std.mem.eql(u8, arg, "nomemo")) {
            memoize = false;
        } else if (std.mem.startsWith(u8, arg, "limit=")) {
            computation_width = try std.fmt.parseInt(u16, arg["limit=".len..], 10);
        } else {
            return error.InvalidArgument;
        }
    }

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

    const pipelines = try allocator.alloc(Pipeline, 100);
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
    const cost_factory = pp.F2.init(60);
    const effective_computation_width = computation_width orelse cost_factory.defaultComputationWidth();

    const t0 = time.lap();
    const best = try t.pickWithOptions(allocator, cost_factory, doc, .{
        .gc_tide = gc_tide,
        .computation_width = computation_width,
        .trace_gc = trace_gc,
        .trace_memo = trace_memo,
        .memoize = memoize,
    });
    const t1 = time.lap();

    const idea = best.idea;
    const rank = idea.gist.rank;

    try writer.print(
        "  rank: overflow={d} height={d} tainted={}\n",
        .{ rank.o, rank.h, best.stat.cope_forced != 0 },
    );
    try writer.print(
        "  layouts: completions={d} frontier={d} queue_peak={d}\n",
        .{ best.stat.completions, best.stat.size, best.stat.peak },
    );
    try writer.print(
        "  computation: width={d} deferred={d} forced={d}\n",
        .{ effective_computation_width, best.stat.cope_deferred, best.stat.cope_forced },
    );
    try writer.print(
        "  memo: enabled={} hits={d} (hcat={d} fork={d}) misses={d} (hcat={d} fork={d}) entries={d}\n\n",
        .{
            memoize,
            best.stat.memo_hits,
            best.stat.memo_hits_hcat,
            best.stat.memo_hits_fork,
            best.stat.memo_misses,
            best.stat.memo_misses_hcat,
            best.stat.memo_misses_fork,
            best.stat.memo_entries,
        },
    );
    try writer.print(
        "  gc: tide={d} collections={d} heap_peak={d} before_peak={d} live_peak={d} live_last={d} copied={d}\n\n",
        .{
            gc_tide,
            best.stat.gc_count,
            best.stat.heap_peak,
            best.stat.gc_before_peak,
            best.stat.gc_live_peak,
            best.stat.gc_live_last,
            best.stat.gc_copied_total,
        },
    );

    try t.emit(writer, idea.node);
    const t3 = time.read();
    try writer.print(
        "  (dump {D}; best {D}; emit {D})\n\n",
        .{ t0, t1, t3 },
    );
    try writer.print("cons: {d} cans: {d}\n", .{
        t.heap.new().hcat.list.items.len,
        t.heap.new().cons.list.items.len,
    });
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
