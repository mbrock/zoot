const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;

// Build a tiny example with just 3 choices
fn buildTinyChoices(t: *pp.Tree) !pp.Node {
    var doc = try t.text("start");

    // Choice 1
    const c1_inline = try t.plus(try t.text(" "), try t.text("A"));
    const c1_multi = try t.plus(pp.Node.nl, try t.text("A"));
    const choice1 = try t.fork(c1_inline, c1_multi);
    doc = try t.plus(doc, choice1);

    // Choice 2
    const c2_inline = try t.plus(try t.text(" "), try t.text("B"));
    const c2_multi = try t.plus(pp.Node.nl, try t.text("B"));
    const choice2 = try t.fork(c2_inline, c2_multi);
    doc = try t.plus(doc, choice2);

    // Choice 3
    const c3_inline = try t.plus(try t.text(" "), try t.text("C"));
    const c3_multi = try t.plus(pp.Node.nl, try t.text("C"));
    const choice3 = try t.fork(c3_inline, c3_multi);
    doc = try t.plus(doc, choice3);

    return doc;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var t = pp.Tree.init(allocator);
    defer t.deinit();

    std.debug.print("\n=== Building doc with 3 choices ===\n", .{});
    const doc = try buildTinyChoices(&t);

    std.debug.print("\n=== Starting layout search (width=80, F2 cost) ===\n\n", .{});

    const cost = pp.F2.init(80);
    const result = try t.pick(allocator, cost, doc);

    std.debug.print("\n=== Search complete ===\n", .{});
    std.debug.print("Completions: {d}\n", .{result.stat.completions});
    std.debug.print("Memo lookups: {d} hits + {d} misses = {d} total\n", .{
        result.stat.memo_hits,
        result.stat.memo_misses,
        result.stat.memo_hits + result.stat.memo_misses,
    });
    std.debug.print("Queue peak: {d}\n", .{result.stat.peak});
    std.debug.print("Final frontier size: {d}\n", .{result.stat.size});
    std.debug.print("Overflow: {d}, Height: {d}\n", .{
        result.idea.gist.rank.o,
        result.idea.gist.rank.h,
    });

    // Emit the result
    std.debug.print("\nResult:\n", .{});
    var buffer: [8192]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&buffer);
    const writer = &stdout_writer.interface;
    try t.emit(writer, result.idea.node);
    try writer.flush();
    std.debug.print("\n", .{});
}
