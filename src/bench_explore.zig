const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;

fn benchSuite(allocator: std.mem.Allocator, name: []const u8, width: u16, n: usize, builder: anytype) !void {
    var t = pp.Tree.init(allocator);
    defer t.deinit();

    var timer = try std.time.Timer.start();
    const doc = try builder(&t, n);
    const build_time = timer.lap();

    const cost = pp.F2.init(width);
    const result = try t.pick(allocator, cost, doc);
    const pick_time = timer.lap();

    const rank = result.idea.gist.rank;

    std.debug.print("{s:20} n={d:4} w={d:3} | ", .{ name, n, width });
    std.debug.print("build:{d:6}µs pick:{d:6}µs | ", .{ build_time / 1000, pick_time / 1000 });
    std.debug.print("compl:{d:5} memo:{d:5}/{d:5}({d:3}%) | ", .{
        result.stat.completions,
        result.stat.memo_hits,
        result.stat.memo_hits + result.stat.memo_misses,
        if (result.stat.memo_hits + result.stat.memo_misses > 0)
            (result.stat.memo_hits * 100) / (result.stat.memo_hits + result.stat.memo_misses)
        else
            0,
    });
    std.debug.print("over:{d:5} h:{d:3}\n", .{ rank.o, rank.h });
}

// Simple concat chain: just linear
fn buildConcatChain(t: *pp.Tree, n: usize) !pp.Node {
    var doc = try t.text("start");
    var i: usize = 0;
    while (i < n) : (i += 1) {
        doc = try t.plus(doc, try t.text(" X"));
    }
    return doc;
}

// Binary tree: exponential nodes
fn buildSExpTree(t: *pp.Tree, depth: usize) !pp.Node {
    if (depth == 0) return try t.text("leaf");

    const left = try buildSExpTree(t, depth - 1);
    const right = try buildSExpTree(t, depth - 1);

    var doc = try t.text("(");
    doc = try t.plus(doc, try t.text("node"));
    doc = try t.plus(doc, try t.text(" "));
    doc = try t.plus(doc, left);
    doc = try t.plus(doc, try t.text(" "));
    doc = try t.plus(doc, right);
    doc = try t.plus(doc, try t.text(")"));
    return doc;
}

// Many choices: tests fork performance
fn buildManyChoices(t: *pp.Tree, n: usize) !pp.Node {
    var doc = try t.text("start");
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const inline_opt = try t.plus(try t.text(" "), try t.text("item"));
        const multiline_opt = try t.plus(pp.Node.nl, try t.text("item"));
        const choice = try t.fork(inline_opt, multiline_opt);
        doc = try t.plus(doc, choice);
    }
    return doc;
}

// Group (flatten test): tests group combinator pattern
fn buildGrouped(t: *pp.Tree, n: usize) !pp.Node {
    var doc = try t.text("func(");
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (i > 0) {
            doc = try t.plus(doc, try t.text(","));
        }
        // Simulate group: fork between flat and not-flat
        const item_flat = try t.plus(try t.text(" "), try t.text("arg"));
        const item_break = try t.plus(pp.Node.nl, try t.nest(2, try t.text("arg")));
        const grouped = try t.fork(item_flat, item_break);
        doc = try t.plus(doc, grouped);
    }
    doc = try t.plus(doc, try t.text(")"));
    return doc;
}

// Nested: tests indentation tracking
fn buildNested(t: *pp.Tree, depth: usize) !pp.Node {
    if (depth == 0) return try t.text("x");

    const inner = try buildNested(t, depth - 1);
    var doc = try t.text("{");
    doc = try t.plus(doc, pp.Node.nl);
    doc = try t.plus(doc, try t.nest(2, inner));
    doc = try t.plus(doc, pp.Node.nl);
    doc = try t.plus(doc, try t.text("}"));
    return doc;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\nPretty Printer Exploration Benchmark\n", .{});
    std.debug.print("=====================================\n\n", .{});

    // Test different widths with same structure
    std.debug.print("--- Width sensitivity (Concat Chain) ---\n", .{});
    try benchSuite(allocator, "Concat", 40, 50, buildConcatChain);
    try benchSuite(allocator, "Concat", 80, 50, buildConcatChain);
    try benchSuite(allocator, "Concat", 120, 50, buildConcatChain);
    std.debug.print("\n", .{});

    // Scale up choices (most interesting for search)
    std.debug.print("--- Many Choices (fork-heavy) ---\n", .{});
    try benchSuite(allocator, "Choices", 80, 3, buildManyChoices);
    try benchSuite(allocator, "Choices", 80, 5, buildManyChoices);
    try benchSuite(allocator, "Choices", 80, 7, buildManyChoices);
    try benchSuite(allocator, "Choices", 80, 10, buildManyChoices);
    try benchSuite(allocator, "Choices", 80, 12, buildManyChoices);
    try benchSuite(allocator, "Choices", 80, 14, buildManyChoices);
    try benchSuite(allocator, "Choices", 80, 22, buildManyChoices);
    std.debug.print("\n", .{});

    // Scale up tree depth
    std.debug.print("--- S-Exp Tree (exponential nodes) ---\n", .{});
    try benchSuite(allocator, "Tree", 80, 3, buildSExpTree);
    try benchSuite(allocator, "Tree", 80, 4, buildSExpTree);
    try benchSuite(allocator, "Tree", 80, 5, buildSExpTree);
    try benchSuite(allocator, "Tree", 80, 6, buildSExpTree);
    std.debug.print("\n", .{});

    // Grouped (simulates group combinator pattern)
    std.debug.print("--- Grouped args (like group combinator) ---\n", .{});
    try benchSuite(allocator, "Grouped", 80, 3, buildGrouped);
    try benchSuite(allocator, "Grouped", 80, 5, buildGrouped);
    try benchSuite(allocator, "Grouped", 80, 7, buildGrouped);
    try benchSuite(allocator, "Grouped", 80, 10, buildGrouped);
    std.debug.print("\n", .{});

    // Nested indentation
    std.debug.print("--- Nested blocks ---\n", .{});
    try benchSuite(allocator, "Nested", 80, 5, buildNested);
    try benchSuite(allocator, "Nested", 80, 7, buildNested);
    try benchSuite(allocator, "Nested", 80, 10, buildNested);
    std.debug.print("\n", .{});
}
