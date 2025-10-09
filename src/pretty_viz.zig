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

pub fn toJson(t1: *Tree, buffer: []u8, node: Node) ![]const u8 {
    var t2 = Tree.init(t1.alloc);
    defer t2.deinit();

    const body = try jsonNode(&t2, t1, node);
    return try t2.show(buffer, body);
}

fn jsonNode(t2: *Tree, t1: *Tree, node: Node) error{OutOfMemory}!Node {
    const id = node.repr();

    const kind_str = switch (node.kind) {
        .text => "text",
        .oper => if (node.data.oper.kind == .plus) "plus" else "fork",
    };

    const label = switch (node.kind) {
        .text => try formatTextNode(t2, t1, node),
        .oper => blk: {
            const oper = node.data.oper;
            break :blk try t2.cat(&.{
                try t2.text(if (oper.kind == .plus) "+" else "?"),
                try t2.when(oper.frob.flat == 1, try t2.text("ᶠ")),
                try t2.when(oper.frob.warp == 1, try t2.text("ʷ")),
                try t2.when(oper.frob.nest != 0, try t2.format("ⁿ{d}", .{oper.frob.nest})),
            });
        },
    };

    const id_field = try jsonField(t2, "id", try t2.quotes(try t2.format("{x}", .{id})));
    const kind_field = try jsonString(t2, "kind", kind_str);
    const label_field = try jsonField(t2, "label", try t2.quotes(label));

    const text_kind_field = if (node.kind == .text) blk: {
        const tk = switch (node.data.text.kind) {
            .pool => "pool",
            .tiny => "tiny",
        };
        break :blk try jsonString(t2, "textKind", tk);
    } else try t2.text("");

    const children_field = if (node.kind == .oper) blk: {
        const oper = node.data.oper;
        const args = if (oper.kind == .plus)
            t1.heap.plus.items[oper.what]
        else
            t1.heap.fork.items[oper.what];

        const left = try jsonNode(t2, t1, args.a);
        const right = try jsonNode(t2, t1, args.b);

        break :blk try jsonField(
            t2,
            "children",
            try t2.brackets(try t2.sepBy(&.{ left, right }, try t2.text(","))),
        );
    } else try t2.text("");

    const fields = if (node.kind == .oper)
        &[_]Node{ id_field, kind_field, label_field, children_field }
    else if (node.kind == .text)
        &[_]Node{ id_field, kind_field, text_kind_field, label_field }
    else
        &[_]Node{ id_field, kind_field, label_field };

    return try t2.braces(try t2.sepBy(fields, try t2.text(",")));
}

pub fn graphviz(t1: *Tree, buffer: []u8, node: Node) ![]const u8 {
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

    return try t2.show(buffer, doc);
}

fn graphvizDoc(t2: *Tree, t1: *Tree, node: Node) error{OutOfMemory}!Node {
    const id = node.repr();

    const label = switch (node.kind) {
        .text => try formatTextNode(t2, t1, node),
        .oper => blk: {
            const oper = node.data.oper;
            break :blk try t2.cat(&.{
                try t2.text(if (oper.kind == .plus) "+" else "?"),
                try t2.when(oper.frob.flat == 1, try t2.text("ᶠ")),
                try t2.when(oper.frob.warp == 1, try t2.text("ʷ")),
                try t2.when(oper.frob.nest != 0, try t2.format("ⁿ{d}", .{oper.frob.nest})),
            });
        },
    };

    const color = switch (node.kind) {
        .text => switch (node.data.text.kind) {
            .pool => "lightcyan",
            .tiny => "lightblue",
        },
        .oper => if (node.data.oper.kind == .plus) "gray20" else "lightyellow",
    };

    const shape = switch (node.kind) {
        .text => switch (node.data.text.kind) {
            .pool => "ellipse",
            .tiny => "box",
        },
        .oper => if (node.data.oper.kind == .plus) "point" else "box",
    };

    const style_attrs = if (node.kind == .oper and node.data.oper.kind == .plus)
        try t2.sepBy(&.{
            try t2.attr("shape", try t2.text(shape)),
            try t2.attr("width", try t2.text("0.15")),
            try t2.attr("fillcolor", try t2.text(color)),
            try t2.attr("style", try t2.text("filled")),
        }, try t2.text(", "))
    else
        try t2.sepBy(&.{
            try t2.attr("label", label),
            try t2.attr("shape", try t2.text(shape)),
            try t2.attr("fillcolor", try t2.text(color)),
            try t2.attr("style", try t2.text("filled")),
        }, try t2.text(", "));

    const node_line = try stmt(t2, try t2.cat(&.{
        try t2.format("n{x} ", .{id}),
        try t2.brackets(style_attrs),
    }));

    // Add edges if this is an oper
    if (node.kind == .oper) {
        const oper = node.data.oper;
        const args = if (oper.kind == .plus)
            t1.heap.plus.items[oper.what]
        else
            t1.heap.fork.items[oper.what];

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
    }

    return node_line;
}

fn formatTextNode(doc_tree: *Tree, data_tree: *Tree, node: Node) !Node {
    std.debug.assert(node.kind == .text);

    return switch (node.data.text.kind) {
        .pool => blk: {
            const pool = node.data.text.data.pool;
            const tail = data_tree.byte.items[pool.text..];
            const span = std.mem.sliceTo(tail, 0);

            break :blk try doc_tree.cat(&.{
                try doc_tree.when(
                    pool.char != 0 and pool.side == .l,
                    try doc_tree.format("{f}", .{std.zig.fmtChar(pool.char)}),
                ),
                try doc_tree.format("{f}", .{std.zig.fmtString(span)}),
                try doc_tree.when(
                    pool.char != 0 and pool.side == .r,
                    try doc_tree.format("{f}", .{std.zig.fmtChar(pool.char)}),
                ),
            });
        },
        .tiny => switch (node.data.text.data.tiny.kind) {
            .splat => switch (node.data.text.data.tiny.data.splat.kind) {
                .rune => blk: {
                    const rune = node.data.text.data.tiny.data.splat.data.rune;
                    if (rune.reps == 0) {
                        break :blk try doc_tree.text("(empty)");
                    } else {
                        break :blk try doc_tree.cat(&.{
                            try doc_tree.format("{f}", .{std.zig.fmtChar(rune.code)}),
                            try doc_tree.when(rune.reps > 1, try doc_tree.format("x{d}", .{rune.reps})),
                        });
                    }
                },
                .utf8 => try doc_tree.text("(utf8)"),
            },
            .ascii => blk: {
                const ascii = node.data.text.data.tiny.data.ascii;
                var bytes: [4]u8 = undefined;
                for (0..4) |i| bytes[i] = ascii.chrs[i];
                const span = std.mem.sliceTo(&bytes, 0);
                break :blk try doc_tree.format("{f}", .{std.zig.fmtString(span)});
            },
        },
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
