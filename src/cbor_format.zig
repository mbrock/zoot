const std = @import("std");
const p = @import("pretty.zig");
const cbor = @import("cbor_json.zig");
const recursive = @import("recursive.zig");

pub fn format(allocator: std.mem.Allocator, input: []const u8, width: u16) ![]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var tree = try p.Tree.init(arena);
    defer tree.deinit();
    const doc = try cbor.parse(&tree, input);
    const best = try recursive.pickWithOptions(&tree, arena, p.F2.init(width), doc, .{});

    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try tree.emit(&output.writer, best.idea.node);
    return output.toOwnedSlice();
}
