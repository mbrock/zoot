//! Exercise the recursive Zig evaluator on the same large JSON-like array as
//! rust/examples/large_array.rs.
//!
//!     zig build stress-recursive -Doptimize=ReleaseFast -- 1600 8
//!
//! Add `-Dprofile-outline=true` to keep `evalHcat` and `evalFork` out of
//! `eval` when comparing generated stack frames.

const std = @import("std");
const zoot = @import("zoot");
const p = zoot.PrettyGoodMachine;
const recursive = zoot.Recursive;

fn arrayDocument(tree: *p.Tree, element_count: usize) !p.Node {
    const elements = try tree.bank.alloc(p.Node, element_count);
    defer tree.bank.free(elements);
    for (elements, 0..) |*element, value| {
        element.* = try tree.format("{d}", .{value});
    }

    const horizontal = try tree.wrap(
        "[",
        try tree.join(elements, try tree.text(", ")),
        "]",
    );

    const vertical_separator = try tree.plus(try tree.text(","), .nl);
    const vertical_body = try tree.join(elements, vertical_separator);
    const vertical = try tree.cat(&.{
        try tree.text("["),
        try tree.nest(2, try tree.plus(.nl, vertical_body)),
        .nl,
        try tree.text("]"),
    });

    return tree.fork(horizontal, vertical);
}

fn run(element_count: usize) !void {
    const allocator = std.heap.page_allocator;
    var tree = try p.Tree.init(allocator);
    errdefer tree.deinit();

    const document = try arrayDocument(&tree, element_count);
    std.debug.print("built\n", .{});

    const best = try recursive.pickWithOptions(
        &tree,
        allocator,
        p.F1.init(80),
        document,
        .{},
    );
    std.debug.print(
        "planned: rank=({d},{d})\n",
        .{ best.idea.gist.rank.o, best.idea.gist.rank.h },
    );

    const output = try allocator.alloc(u8, element_count * 32 + 1024);
    defer allocator.free(output);
    var sink = std.Io.Writer.fixed(output);
    try tree.emit(&sink, best.idea.node);
    std.debug.print("rendered: {d} bytes\n", .{sink.buffered().len});

    tree.deinit();
    std.debug.print("dropped\n", .{});
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();

    const element_count = if (args.next()) |argument|
        try std.fmt.parseInt(usize, argument, 10)
    else
        10_000;
    const stack_mib = if (args.next()) |argument|
        try std.fmt.parseInt(usize, argument, 10)
    else
        8;
    if (args.next() != null) return error.TooManyArguments;

    std.debug.print(
        "large JSON array: elements={d} stack={d} MiB optimized={}\n",
        .{ element_count, stack_mib, @import("builtin").mode != .Debug },
    );
    const thread = try std.Thread.spawn(
        .{ .stack_size = stack_mib * 1024 * 1024 },
        run,
        .{element_count},
    );
    thread.join();
}
