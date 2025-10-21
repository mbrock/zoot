const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;
const dump = @import("zoot").dump;

pub fn main() !void {
    var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var t = pp.Tree.init(allocator);
    defer t.deinit();

    // Create a simple structure that should fit at width=40
    const Data = struct {
        name: []const u8,
        enabled: bool,
        count: u32,
    };

    const data = Data{
        .name = "test",
        .enabled = true,
        .count = 42,
    };

    const doc = try dump.dump(&t, data);
    const cost = pp.F2.init(40);
    const best = try t.pick(allocator, cost, doc);

    std.debug.print("\n=== RESULT ===\n", .{});
    std.debug.print("overflow: {d}\n", .{best.idea.gist.rank.o});
    std.debug.print("height: {d}\n", .{best.idea.gist.rank.h});
    std.debug.print("tainted: {}\n", .{cost.icky(best.idea.gist.rank)});
    std.debug.print("last: {d}\n", .{best.idea.gist.last});
    std.debug.print("\n=== EMITTED ===\n", .{});

    var buffer: [4096]u8 = undefined;
    var writer = std.io.Writer.fixed(buffer[0..]);
    try t.emit(&writer, best.idea.node);
    const rendered = writer.buffered();
    std.debug.print("{s}\n", .{rendered});
}
