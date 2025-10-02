const std = @import("std");
const zoot = @import("zoot");

pub fn main() !void {
    var buffer: [80]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    var tree = zoot.TreePrinter.empty;

    try tree.show(writer, true);
    try writer.writeAll("tree\n");
    try tree.push(true);
    try tree.show(writer, true);
    try writer.writeAll("hello\n");
    try tree.show(writer, false);
    try writer.writeAll("hello\n");
    tree.pop();
    try tree.show(writer, false);
    try writer.writeAll("over\n");
}
