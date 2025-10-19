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

    try writer.print("┏━ CEK debug ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    const Cost = pp.F2;
    const cost_model = Cost.init(80);
    const cost_factory = cost_model.factory();

    var frames = pp.List(pp.Kont).init(allocator);
    defer frames.deinit();

    const k_done = try frames.push(allocator, .{ .done = {} });
    var machine = pp.Exec{
        .eval = .{
            .node = doc,
            .crux = .{},
            .then = k_done,
        },
    };

    var loop = pp.Loop{
        .tree = &t,
        .bank = allocator,
        .cost = cost_factory,
        .node = doc,
        .info = null,
    };

    const debug_limit: usize = 12;
    var step_index: usize = 0;
    while (step_index < debug_limit) : (step_index += 1) {
        try writer.print("┃ step {d: >2} → {s}\n", .{ step_index, @tagName(machine) });

        var stop = false;
        switch (machine) {
            .eval => |state| {
                try writer.print(
                    "┃   eval node={s} head={d} base={d} rows={d}\n",
                    .{
                        @tagName(state.node.tag),
                        state.crux.head,
                        state.crux.base,
                        state.crux.rows,
                    },
                );
            },
            .give => |state| {
                try writer.print(
                    "┃   ret last={d} rows={d} taint={}\n",
                    .{
                        state.idea.last,
                        state.idea.rows,
                        state.idea.icky,
                    },
                );
            },
            .fork => |state| {
                try writer.print(
                    "┃   fork L={s} R={s}\n",
                    .{
                        @tagName(state.left.node.tag),
                        @tagName(state.right.node.tag),
                    },
                );
                stop = true;
            },
            .done => |state| {
                try writer.print(
                    "┃   done last={d} rows={d} taint={}\n",
                    .{
                        state.idea.last,
                        state.idea.rows,
                        state.idea.icky,
                    },
                );
                stop = true;
            },
        }

        if (stop) break;

        loop.machineStep(&frames, &machine, null, null) catch |err| {
            try writer.print("┃   step error: {s}\n", .{@errorName(err)});
            break;
        };
    }
    try writer.print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    const best = try t.best(allocator, cost_factory, doc, writer);
    const t1 = time.lap();

    // var hest = try pp.Maze.hest(&t, allocator, pp.F2.init(40), doc, writer);
    // defer hest.deinit(allocator);
    const t2 = time.lap();

    const measure = best.measure;
    const rank = Cost.Rank.fromU64(measure.rank);

    try writer.print(
        "  rank: overflow={d} height={d} tainted={}\n",
        .{ rank.o, rank.h, measure.icky },
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
        "  (dump {D}; best {D}; hest {D}; emit {D})\n\n",
        .{ t0, t1, t2, t3 },
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
