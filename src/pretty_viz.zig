const std = @import("std");
const pretty = @import("pretty.zig");

const Tree = pretty.Tree;
const Node = pretty.Node;

fn jsonField(t: *Tree, key: [:0]const u8, val: Node) !Node {
    return try t.sepBy(&.{
        try t.quotes(try t.text(key)),
        val,
    }, try t.text(":"));
}

fn jsonString(t: *Tree, key: [:0]const u8, val: [:0]const u8) !Node {
    return try jsonField(t, key, try t.quotes(try t.text(val)));
}

fn stmt(t: *Tree, s: Node) !Node {
    return try t.cat(&.{ s, try t.text(";") });
}

pub fn toJson(t1: *Tree, sink: *std.Io.Writer, node: Node) !void {
    var t2 = Tree.init(t1.alloc);
    defer t2.deinit();

    const tree_field = try jsonField(&t2, "tree", try jsonNode(&t2, t1, node));
    const maze_field = try jsonField(&t2, "maze", try jsonMaze(&t2, t1));

    const doc = try t2.braces(try t2.sepBy(&.{ tree_field, maze_field }, try t2.text(",")));
    try t2.emit(sink, doc);
}

fn jsonNode(t2: *Tree, t1: *Tree, node: Node) error{OutOfMemory}!Node {
    const id = node.repr();

    const kind_str = switch (node.tag) {
        .cons => "plus",
        .fork => "fork",
        else => "text",
    };

    const label = switch (node.look()) {
        .span, .quad, .trip, .rune => try formatTextNode(t2, t1, node),
        .cons, .fork => |oper| try t2.cat(&.{
            try t2.text(if (node.tag == .cons) "+" else "?"),
            try t2.when(oper.frob.flat == 1, try t2.text("ᶠ")),
            try t2.when(oper.frob.warp == 1, try t2.text("ʷ")),
            try t2.when(oper.frob.nest != 0, try t2.format("ⁿ{d}", .{oper.frob.nest})),
        }),
        .cont => unreachable,
    };

    const id_field = try jsonField(t2, "id", try t2.quotes(try t2.format("{x}", .{id})));
    const kind_field = try jsonString(t2, "kind", kind_str);
    const label_field = try jsonField(t2, "label", try t2.quotes(label));

    const text_kind_field = switch (node.tag) {
        .span => try jsonString(t2, "textKind", "span"),
        .quad => try jsonString(t2, "textKind", "quad"),
        .trip => try jsonString(t2, "textKind", "trip"),
        .rune => try jsonString(t2, "textKind", "rune"),
        else => try t2.text(""),
    };

    const children_field = switch (node.look()) {
        .cons, .fork => |oper| blk: {
            const args = if (node.tag == .cons)
                t1.heap.plus.items[oper.item]
            else
                t1.heap.fork.items[oper.item];

            const left = try jsonNode(t2, t1, args.a);
            const right = try jsonNode(t2, t1, args.b);

            break :blk try jsonField(
                t2,
                "children",
                try t2.brackets(try t2.sepBy(&.{ left, right }, try t2.text(","))),
            );
        },
        else => try t2.text(""),
    };

    const fields = switch (node.tag) {
        .cons, .fork => &[_]Node{ id_field, kind_field, label_field, children_field },
        .span, .quad, .trip, .rune => &[_]Node{ id_field, kind_field, text_kind_field, label_field },
        .cont => unreachable,
    };

    return try t2.braces(try t2.sepBy(fields, try t2.text(",")));
}

fn jsonMaze(t2: *Tree, t1: *Tree) !Node {
    var frames = std.ArrayListUnmanaged(Node){};
    defer frames.deinit(t2.alloc);

    for (t1.heap.maze.items, 0..) |frame, idx| {
        const slot_field = try jsonField(t2, "slot", try t2.format("{d}", .{idx}));
        const next_field = try jsonField(t2, "next", try t2.quotes(try t2.format("{x}", .{frame.a.repr()})));
        const next_kind_field = try jsonString(t2, "nextKind", @tagName(frame.a.tag));
        const tail_kind_field = try jsonString(t2, "tailKind", @tagName(frame.b.tag));
        const tail_slot_field = try jsonField(t2, "tailSlot", try t2.format("{d}", .{frame.b.payload}));

        const span = &[_]Node{ slot_field, next_field, next_kind_field, tail_kind_field, tail_slot_field };
        try frames.append(t2.alloc, try t2.braces(try t2.sepBy(span, try t2.text(","))));
    }

    const contents = if (frames.items.len == 0)
        try t2.text("")
    else
        try t2.sepBy(frames.items, try t2.text(","));

    return try t2.brackets(contents);
}

pub fn graphviz(t1: *Tree, sink: *std.Io.Writer, node: Node) !void {
    var t2 = Tree.init(t1.alloc);
    defer t2.deinit();

    const body = try graphvizDoc(&t2, t1, node);

    const doc = try t2.block(
        try t2.text("digraph Tree"),
        try t2.sepBy(&.{
            try stmt(&t2, try t2.text("ordering=out")),
            try stmt(&t2, try t2.text("ranksep=0.5")),
            try stmt(&t2, try t2.text("node [shape=box, fontname=\"monospace\"]")),
            body,
        }, Node.nl),
        2,
    );

    try t2.emit(sink, doc);
}

fn graphvizDoc(t2: *Tree, t1: *Tree, node: Node) error{OutOfMemory}!Node {
    const id = node.repr();

    const label = switch (node.look()) {
        .span, .quad, .trip, .rune => try formatTextNode(t2, t1, node),
        .cons, .fork => |oper| try t2.cat(&.{
            try t2.text(if (node.tag == .cons) "+" else "?"),
            try t2.when(oper.frob.flat == 1, try t2.text("ᶠ")),
            try t2.when(oper.frob.warp == 1, try t2.text("ʷ")),
            try t2.when(oper.frob.nest != 0, try t2.format("ⁿ{d}", .{oper.frob.nest})),
        }),
        .cont => unreachable,
    };

    const color = switch (node.tag) {
        .span => "lightcyan",
        .quad, .trip, .rune => "lightblue",
        .cons => "gray20",
        .fork => "lightyellow",
        .cont => unreachable,
    };

    const shape = switch (node.tag) {
        .span => "ellipse",
        .quad, .trip, .rune => "box",
        .cons => "point",
        .fork => "box",
        .cont => unreachable,
    };

    const style_attrs = switch (node.tag) {
        .cons => try t2.sepBy(&.{
            try t2.attr("shape", try t2.text(shape)),
            try t2.attr("width", try t2.text("0.15")),
            try t2.attr("fillcolor", try t2.text(color)),
            try t2.attr("style", try t2.text("filled")),
        }, try t2.text(", ")),
        else => try t2.sepBy(&.{
            try t2.attr("label", label),
            try t2.attr("shape", try t2.text(shape)),
            try t2.attr("fillcolor", try t2.text(color)),
            try t2.attr("style", try t2.text("filled")),
        }, try t2.text(", ")),
    };

    const node_line = try stmt(t2, try t2.cat(&.{
        try t2.format("n{x} ", .{id}),
        try t2.brackets(style_attrs),
    }));

    // Add edges if this is an oper
    switch (node.look()) {
        .cons, .fork => |oper| {
            const args = if (node.tag == .cons)
                t1.heap.plus.items[oper.item]
            else
                t1.heap.fork.items[oper.item];

            const left_edge = try stmt(t2, try t2.cat(&.{
                try t2.format("n{x}:sw -> n{x} ", .{ id, args.a.repr() }),
                try t2.brackets(try t2.attr("color", try t2.text("blue"))),
            }));

            const right_edge = try stmt(t2, try t2.cat(&.{
                try t2.format("n{x}:se -> n{x} ", .{ id, args.b.repr() }),
                try t2.brackets(try t2.attr("color", try t2.text("red"))),
            }));

            return try t2.sepBy(
                &.{
                    node_line,
                    try graphvizDoc(t2, t1, args.a),
                    left_edge,
                    try graphvizDoc(t2, t1, args.b),
                    right_edge,
                },
                Node.nl,
            );
        },
        .span, .quad, .trip, .rune => {},
        .cont => unreachable,
    }

    return node_line;
}

fn formatTextNode(doc_tree: *Tree, data_tree: *Tree, node: Node) !Node {
    return switch (node.look()) {
        .span => |span_node| blk: {
            const tail = data_tree.byte.items[span_node.text..];
            const slice = std.mem.sliceTo(tail, 0);

            break :blk try doc_tree.cat(&.{
                try doc_tree.when(
                    span_node.char != 0 and span_node.side == .lchr,
                    try doc_tree.format("{f}", .{std.zig.fmtChar(@as(u21, span_node.char))}),
                ),
                try doc_tree.format("{f}", .{std.zig.fmtString(slice)}),
                try doc_tree.when(
                    span_node.char != 0 and span_node.side == .rchr,
                    try doc_tree.format("{f}", .{std.zig.fmtChar(@as(u21, span_node.char))}),
                ),
            });
        },
        .quad => |quad| blk: {
            var bytes = [_]u8{
                @as(u8, quad.ch0),
                @as(u8, quad.ch1),
                @as(u8, quad.ch2),
                @as(u8, quad.ch3),
            };
            const slice = std.mem.sliceTo(&bytes, 0);
            break :blk try doc_tree.format("{f}", .{std.zig.fmtString(slice)});
        },
        .trip => try doc_tree.text("(utf8)"),
        .rune => |rune| blk: {
            if (rune.reps == 0) {
                break :blk try doc_tree.text("(empty)");
            } else {
                break :blk try doc_tree.cat(&.{
                    try doc_tree.format("{f}", .{std.zig.fmtChar(@as(u21, rune.code))}),
                    try doc_tree.when(rune.reps > 1, try doc_tree.format("x{d}", .{rune.reps})),
                });
            }
        },
        .cons, .fork => unreachable,
        .cont => unreachable,
    };
}

const expect = std.testing.expect;

test "graphviz output" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    // Create: warp(nest(2, ("foo" <> nl) <> "bar"))
    const inner = try t.plus(
        try t.plus(try t.text("foo"), Node.nl),
        try t.text("bar"),
    );
    const doc = try t.warp(try t.nest(2, inner));

    var buffer: [1024]u8 = undefined;
    const dot = try graphviz(&t, &buffer, doc);

    // Just verify it contains expected elements
    try expect(std.mem.indexOf(u8, dot, "digraph Tree") != null);
    try expect(std.mem.indexOf(u8, dot, "foo") != null);
    try expect(std.mem.indexOf(u8, dot, "bar") != null);
}
