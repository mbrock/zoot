const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;

// Build a tiny example with just 3 choices
fn buildChoices(t: *pp.Tree, n: usize) !pp.Node {
    var doc = try t.text("start");

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const inline_opt = try t.plus(try t.text(" "), try t.text("X"));
        const multiline_opt = try t.plus(pp.Node.nl, try t.text("X"));
        const choice = try t.fork(inline_opt, multiline_opt);
        doc = try t.plus(doc, choice);
    }

    return doc;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sizes = [_]usize{ 3, 5, 7, 10, 12 };

    std.debug.print("\n{s:6} | {s:12} | {s:12} | {s:8}\n", .{
        "Forks",
        "Memo Hits",
        "Memo Misses",
        "Total",
    });
    std.debug.print("{s:-<6}-+-{s:-<12}-+-{s:-<12}-+-{s:-<8}\n", .{ "", "", "", "" });

    for (sizes) |size| {
        var t = pp.Tree.init(allocator);
        defer t.deinit();

        const doc = try buildChoices(&t, size);
        const cost = pp.F2.init(80);
        const result = try t.pick(allocator, cost, doc);

        const total = result.stat.memo_hits + result.stat.memo_misses;

        std.debug.print("{d:6} | {d:12} | {d:12} | {d:8}\n", .{
            size,
            result.stat.memo_hits,
            result.stat.memo_misses,
            total,
        });

        // Show theoretical 2^n
        const theoretical = @as(usize, 1) << @as(u6, @intCast(size));
        std.debug.print("       | (2^{d} = {d} theoretical combinations)\n", .{ size, theoretical });
    }

    std.debug.print("\nNote: If exploring 2^N combinations, memo lookups would be O(2^N)\n", .{});
    std.debug.print("Observe: At N=12, we have ~12K lookups but 2^12 = 4096 combinations\n", .{});
    std.debug.print("This suggests we're doing ~3x more work than just enumerating all 2^N layouts!\n", .{});
}
