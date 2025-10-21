const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;

const BenchResult = struct {
    name: []const u8,
    doc_time_ns: u64,
    pick_time_ns: u64,
    completions: usize,
    memo_hits: usize,
    memo_misses: usize,
    memo_entries: usize,
    frontier_size: usize,
    queue_peak: usize,
    overflow: u32,
    height: u32,
};

fn printResult(writer: anytype, result: BenchResult) !void {
    try writer.print("\n=== {s} ===\n", .{result.name});
    try writer.print("  Document construction: {d} µs\n", .{result.doc_time_ns / 1000});
    try writer.print("  Layout search (pick):  {d} µs\n", .{result.pick_time_ns / 1000});
    try writer.print("  Total:                 {d} µs\n", .{(result.doc_time_ns + result.pick_time_ns) / 1000});
    try writer.print("  Layouts: completions={d} frontier={d} peak={d}\n", .{
        result.completions,
        result.frontier_size,
        result.queue_peak,
    });
    try writer.print("  Memo: hits={d} misses={d} entries={d} hit_rate={d:.1}%\n", .{
        result.memo_hits,
        result.memo_misses,
        result.memo_entries,
        if (result.memo_hits + result.memo_misses > 0)
            (@as(f64, @floatFromInt(result.memo_hits)) * 100.0 / @as(f64, @floatFromInt(result.memo_hits + result.memo_misses)))
        else
            0.0,
    });
    try writer.print("  Result: overflow={d} height={d}\n", .{ result.overflow, result.height });
}

// Benchmark 1: Deep concatenation chain (from paper Section 8.1)
fn benchConcatChain(allocator: std.mem.Allocator, n: usize, width: u16) !BenchResult {
    var t = pp.Tree.init(allocator);
    defer t.deinit();

    var timer = try std.time.Timer.start();

    // Build: text("A") ++ text("B") ++ ... (n times)
    var doc = try t.text("A");
    var i: usize = 1;
    while (i < n) : (i += 1) {
        doc = try t.plus(doc, try t.text("B"));
    }

    const doc_time = timer.lap();

    const cost_factory = pp.F2.init(width);
    const best = try t.pick(allocator, cost_factory, doc);
    const pick_time = timer.lap();

    const rank = best.idea.gist.rank;

    return BenchResult{
        .name = "Concat Chain",
        .doc_time_ns = doc_time,
        .pick_time_ns = pick_time,
        .completions = best.stat.completions,
        .memo_hits = best.stat.memo_hits,
        .memo_misses = best.stat.memo_misses,
        .memo_entries = best.stat.memo_entries,
        .frontier_size = best.stat.size,
        .queue_peak = best.stat.peak,
        .overflow = rank.o,
        .height = rank.h,
    };
}

// Benchmark 2: Binary tree S-expression (from paper Section 8.1)
fn benchSExpTree(allocator: std.mem.Allocator, depth: usize, width: u16) !BenchResult {
    var t = pp.Tree.init(allocator);
    defer t.deinit();

    var timer = try std.time.Timer.start();

    const doc = try buildSExpTree(&t, depth);
    const doc_time = timer.lap();

    const cost_factory = pp.F2.init(width);
    const best = try t.pick(allocator, cost_factory, doc);
    const pick_time = timer.lap();

    const rank = best.idea.gist.rank;

    return BenchResult{
        .name = "S-Exp Tree",
        .doc_time_ns = doc_time,
        .pick_time_ns = pick_time,
        .completions = best.stat.completions,
        .memo_hits = best.stat.memo_hits,
        .memo_misses = best.stat.memo_misses,
        .memo_entries = best.stat.memo_entries,
        .frontier_size = best.stat.size,
        .queue_peak = best.stat.peak,
        .overflow = rank.o,
        .height = rank.h,
    };
}

fn buildSExpTree(t: *pp.Tree, depth: usize) !pp.Node {
    if (depth == 0) {
        return try t.text("leaf");
    }

    const left = try buildSExpTree(t, depth - 1);
    const right = try buildSExpTree(t, depth - 1);

    // Build: (lparen, "node", space, left, space, right, rparen)
    var doc = try t.text("(");
    doc = try t.plus(doc, try t.text("node"));
    doc = try t.plus(doc, try t.text(" "));
    doc = try t.plus(doc, left);
    doc = try t.plus(doc, try t.text(" "));
    doc = try t.plus(doc, right);
    doc = try t.plus(doc, try t.text(")"));

    return doc;
}

// Benchmark 3: Many choices (fork-heavy)
fn benchManyChoices(allocator: std.mem.Allocator, n: usize, width: u16) !BenchResult {
    var t = pp.Tree.init(allocator);
    defer t.deinit();

    var timer = try std.time.Timer.start();

    // Build n choices between inline and multiline layouts
    var doc = try t.text("start");
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const inline_opt = try t.plus(
            try t.text(" item"),
            try t.text("X"),
        );
        const multiline_opt = try t.plus(
            try t.plus(pp.Node.nl, try t.text("item")),
            try t.text("X"),
        );
        const choice = try t.fork(inline_opt, multiline_opt);
        doc = try t.plus(doc, choice);
    }

    const doc_time = timer.lap();

    const cost_factory = pp.F2.init(width);
    const best = try t.pick(allocator, cost_factory, doc);
    const pick_time = timer.lap();

    const rank = best.idea.gist.rank;

    return BenchResult{
        .name = "Many Choices",
        .doc_time_ns = doc_time,
        .pick_time_ns = pick_time,
        .completions = best.stat.completions,
        .memo_hits = best.stat.memo_hits,
        .memo_misses = best.stat.memo_misses,
        .memo_entries = best.stat.memo_entries,
        .frontier_size = best.stat.size,
        .queue_peak = best.stat.peak,
        .overflow = rank.o,
        .height = rank.h,
    };
}

// Benchmark 4: Nested indentation
fn benchNestedIndent(allocator: std.mem.Allocator, depth: usize, width: u16) !BenchResult {
    var t = pp.Tree.init(allocator);
    defer t.deinit();

    var timer = try std.time.Timer.start();

    const doc = try buildNestedIndent(&t, depth);
    const doc_time = timer.lap();

    const cost_factory = pp.F2.init(width);
    const best = try t.pick(allocator, cost_factory, doc);
    const pick_time = timer.lap();

    const rank = best.idea.gist.rank;

    return BenchResult{
        .name = "Nested Indent",
        .doc_time_ns = doc_time,
        .pick_time_ns = pick_time,
        .completions = best.stat.completions,
        .memo_hits = best.stat.memo_hits,
        .memo_misses = best.stat.memo_misses,
        .memo_entries = best.stat.memo_entries,
        .frontier_size = best.stat.size,
        .queue_peak = best.stat.peak,
        .overflow = rank.o,
        .height = rank.h,
    };
}

fn buildNestedIndent(t: *pp.Tree, depth: usize) !pp.Node {
    if (depth == 0) {
        return try t.text("body");
    }

    const inner = try buildNestedIndent(t, depth - 1);

    // Build: "{\n" ++ nest(2, inner) ++ "\n}"
    var doc = try t.text("{");
    doc = try t.plus(doc, pp.Node.nl);
    doc = try t.plus(doc, try t.nest(2, inner));
    doc = try t.plus(doc, pp.Node.nl);
    doc = try t.plus(doc, try t.text("}"));

    return doc;
}

// Benchmark 5: JSON-like structure
fn benchJSON(allocator: std.mem.Allocator, n_fields: usize, width: u16) !BenchResult {
    var t = pp.Tree.init(allocator);
    defer t.deinit();

    var timer = try std.time.Timer.start();

    var doc = try t.text("{");
    doc = try t.plus(doc, pp.Node.nl);

    var i: usize = 0;
    while (i < n_fields) : (i += 1) {
        var field = try t.text("  \"field\": \"value\"");

        if (i < n_fields - 1) {
            field = try t.plus(field, try t.text(","));
        }

        field = try t.plus(field, pp.Node.nl);
        doc = try t.plus(doc, field);
    }

    doc = try t.plus(doc, try t.text("}"));

    const doc_time = timer.lap();

    const cost_factory = pp.F2.init(width);
    const best = try t.pick(allocator, cost_factory, doc);
    const pick_time = timer.lap();

    const rank = best.idea.gist.rank;

    return BenchResult{
        .name = "JSON Object",
        .doc_time_ns = doc_time,
        .pick_time_ns = pick_time,
        .completions = best.stat.completions,
        .memo_hits = best.stat.memo_hits,
        .memo_misses = best.stat.memo_misses,
        .memo_entries = best.stat.memo_entries,
        .frontier_size = best.stat.size,
        .queue_peak = best.stat.peak,
        .overflow = rank.o,
        .height = rank.h,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer: [8192]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    try writer.writeAll("Pretty Printer Benchmarks (Zig)\n");
    try writer.writeAll("================================\n");
    try writer.print("Build mode: {s}\n", .{@tagName(@import("builtin").mode)});
    try writer.writeAll("\n");

    const width: u16 = 80;

    // Run benchmarks (small sizes for speed)
    {
        const result = try benchConcatChain(allocator, 50, width);
        try printResult(writer, result);
    }

    {
        const result = try benchSExpTree(allocator, 5, width);
        try printResult(writer, result);
    }

    {
        const result = try benchManyChoices(allocator, 10, width);
        try printResult(writer, result);
    }

    {
        const result = try benchNestedIndent(allocator, 5, width);
        try printResult(writer, result);
    }

    {
        const result = try benchJSON(allocator, 20, width);
        try printResult(writer, result);
    }

    try writer.writeAll("\nAll benchmarks completed!\n");
}
