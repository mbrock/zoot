const std = @import("std");
const zoot = @import("zoot");

fn printBigTree(
    writer: *std.Io.Writer,
    tree: *zoot.TreePrinter,
    depth: u32,
    max_depth: u32,
    node_count: *u32,
) !void {
    if (depth >= max_depth or node_count.* >= 100000) return;

    const has_more = depth < max_depth - 1 and node_count.* < 99990;

    try tree.show(writer, has_more);
    try writer.print("node {d}\n", .{node_count.*});
    node_count.* += 1;

    if (has_more) {
        try tree.push(true);

        // Print 2-3 children at this level
        const children = if (depth % 3 == 0) @as(u32, 3) else 2;
        var i: u32 = 0;
        while (i < children and node_count.* < 100000) : (i += 1) {
            try printBigTree(writer, tree, depth + 1, max_depth, node_count);
        }

        tree.pop();
    }
}

pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    var tree = zoot.TreePrinter.empty;
    var node_count: u32 = 0;

    try printBigTree(writer, &tree, 0, 32, &node_count);
}
