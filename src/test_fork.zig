const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;

pub fn main() !void {
    var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tree = pp.Tree.init(allocator);
    defer tree.deinit();

    // Nested choice to test both fork branches are explored:
    // fork(hcat("aaa", "bbb"), hcat("x", "y"))
    // At width 5:
    //   "aaabbb" = overflow 1
    //   "xy" = no overflow
    // Should pick "xy"

    const left = try tree.plus(
        try tree.text("aaa"),
        try tree.text("bbb"),
    );
    const right = try tree.plus(
        try tree.text("x"),
        try tree.text("y"),
    );
    const doc = try tree.fork(left, right);

    const cost = pp.F2.init(5); // Width = 5
    const best = try tree.pick(allocator, cost, doc);

    std.debug.print("\nResult:\n", .{});
    std.debug.print("  overflow: {d}\n", .{best.idea.gist.rank.o});
    std.debug.print("  height: {d}\n", .{best.idea.gist.rank.h});
    std.debug.print("  tainted: {}\n", .{cost.icky(best.idea.gist.rank)});
    std.debug.print("  completions: {d}\n", .{best.stat.completions});

    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(buffer[0..]);
    try tree.emit(&writer, best.idea.node);
    const rendered = writer.buffered();
    std.debug.print("  text: \"{s}\"\n", .{rendered});
}
