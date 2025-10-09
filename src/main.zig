const std = @import("std");
const pretty = @import("zoot").PrettyGoodMachine;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a more elaborate nested structure
    var tree = pretty.Tree.init(allocator);
    defer tree.deinit();

    // Build a complex nested expression: if (x > 0) { fooFunction(alpha, beta); barFunction(); }
    const condition = try tree.cat(&.{
        try tree.text("x"),
        try tree.text(" "),
        try tree.text(">"),
        try tree.text(" "),
        try tree.text("0"),
    });

    const call1_args = try tree.cat(&.{
        try tree.text("alpha"),
        try tree.text(","),
        try tree.fork(
            try tree.text(" "),
            try tree.plus(pretty.Node.nl, try tree.text("  ")),
        ),
        try tree.text("beta"),
    });

    const call1 = try tree.cat(&.{
        try tree.text("fooFunction"),
        try tree.parens(call1_args),
        try tree.text(";"),
    });

    const call2 = try tree.cat(&.{
        try tree.text("barFunction"),
        try tree.text("()"),
        try tree.text(";"),
    });

    const body = try tree.sepBy(&.{ call1, call2 }, try tree.fork(
        try tree.text(" "),
        pretty.Node.nl,
    ));

    const if_stmt = try tree.cat(&.{
        try tree.text("if"),
        try tree.text(" "),
        try tree.parens(condition),
        try tree.text(" "),
        try tree.braces(try tree.cat(&.{
            try tree.fork(try tree.text(" "), pretty.Node.nl),
            try tree.nest(2, body),
            try tree.fork(try tree.text(" "), pretty.Node.nl),
        })),
    });

    var buffer2: [65536]u8 = undefined;
    const dot2 = try tree.graphviz(&buffer2, if_stmt);

    // Write to file
    const file = try std.fs.cwd().createFile("graphviz.dot", .{});
    defer file.close();
    try file.writeAll(dot2);

    std.debug.print("Generated graphviz.dot with {d} bytes\n", .{dot2.len});
    std.debug.print("Run: dot -Tpdf graphviz.dot -o graphviz.pdf\n", .{});
}
