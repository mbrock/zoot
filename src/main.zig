const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;
const viz = @import("zoot").PrettyViz;
const dump = @import("zoot").dump;
const recursive = @import("zoot").Recursive;

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

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();
    var gc_tide = (pp.PickOptions{}).gc_tide;
    var computation_width: ?u16 = null;
    var trace_gc = false;
    var trace_memo = false;
    var memoize = true;
    var use_recursive = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "trace")) {
            trace_gc = true;
        } else if (std.mem.eql(u8, arg, "memodump")) {
            trace_memo = true;
        } else if (std.mem.eql(u8, arg, "nomemo")) {
            memoize = false;
        } else if (std.mem.eql(u8, arg, "recursive")) {
            use_recursive = true;
        } else if (std.mem.startsWith(u8, arg, "limit=")) {
            computation_width = try std.fmt.parseInt(u16, arg["limit=".len..], 10);
        } else if (arg.len != 0 and std.ascii.isDigit(arg[0])) {
            gc_tide = try std.fmt.parseInt(usize, arg, 10);
        } else {
            return error.InvalidArgument;
        }
    }

    var buffer: [8192]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer = stdout_file.writer(init.io, &buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    var t = try pp.Tree.init(allocator);
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

    var checkpoint = std.Io.Clock.Timestamp.now(init.io, .awake);
    const doc = try dump.dump(&t, pipelines);
    const cost_factory = pp.F2.init(60);
    const effective_computation_width = computation_width orelse cost_factory.defaultComputationWidth();

    var now = std.Io.Clock.Timestamp.now(init.io, .awake);
    const t0 = checkpoint.durationTo(now).raw;
    checkpoint = now;
    const options: pp.PickOptions = .{
        .gc_tide = gc_tide,
        .computation_width = computation_width,
        .trace_gc = trace_gc,
        .trace_memo = trace_memo,
        .memoize = memoize,
    };
    var stat: pp.Stat = .{};
    const best = if (use_recursive)
        try recursive.pickWithStatistics(&t, allocator, cost_factory, doc, options, &stat)
    else
        try t.pickWithStatistics(allocator, cost_factory, doc, options, &stat);
    now = std.Io.Clock.Timestamp.now(init.io, .awake);
    const t1 = checkpoint.durationTo(now).raw;
    checkpoint = now;

    const idea = best.idea;
    const rank = idea.gist.rank;

    try writer.print(
        "  rank: overflow={d} height={d} tainted={}\n",
        .{ rank.o, rank.h, stat.cope_forced != 0 },
    );
    try writer.print(
        "  layouts: completions={d} frontier={d} queue_peak={d}\n",
        .{ stat.completions, stat.size, stat.peak },
    );
    try writer.print(
        "  computation: width={d} deferred={d} forced={d}\n",
        .{ effective_computation_width, stat.cope_deferred, stat.cope_forced },
    );
    try writer.print(
        "  memo: enabled={} hits={d} (hcat={d} fork={d}) misses={d} (hcat={d} fork={d}) entries={d}\n\n",
        .{
            memoize,
            stat.memo_hits,
            stat.memo_hits_hcat,
            stat.memo_hits_fork,
            stat.memo_misses,
            stat.memo_misses_hcat,
            stat.memo_misses_fork,
            stat.memo_entries,
        },
    );
    try writer.print(
        "  gc: tide={d} collections={d} heap_peak={d} before_peak={d} live_peak={d} live_last={d} copied={d}\n\n",
        .{
            gc_tide,
            stat.gc_count,
            stat.heap_peak,
            stat.gc_before_peak,
            stat.gc_live_peak,
            stat.gc_live_last,
            stat.gc_copied_total,
        },
    );

    try t.emit(writer, idea.node);
    const t3 = checkpoint.durationTo(std.Io.Clock.Timestamp.now(init.io, .awake)).raw;
    try writer.print(
        "  (dump {d:.3}ms; best {d:.3}ms; emit {d:.3}ms)\n\n",
        .{
            @as(f64, @floatFromInt(t0.nanoseconds)) / std.time.ns_per_ms,
            @as(f64, @floatFromInt(t1.nanoseconds)) / std.time.ns_per_ms,
            @as(f64, @floatFromInt(t3.nanoseconds)) / std.time.ns_per_ms,
        },
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
