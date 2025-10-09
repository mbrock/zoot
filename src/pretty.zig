const std = @import("std");

pub const Sink = struct {
    tree: *Tree,
    out: *std.Io.Writer,

    /// current column
    head: u16 = 0,
    /// indent column
    base: u16 = 0,
    /// treat ␤ as ␠?
    flat: bool = false,

    pub fn writeString(sink: @This(), what: u21) !void {
        const tail = sink.tree.heap.byte.items[what..];
        const span = std.mem.sliceTo(tail, 0);
        try sink.out.writeAll(span);
    }

    pub fn newline(sink: *@This()) !void {
        if (sink.flat)
            try sink.out.writeByte(' ')
        else {
            try sink.out.writeByte('\n');
            try sink.out.splatByteAll(' ', sink.base);
        }
    }

    pub fn setFlat(sink: *@This(), flat: bool) bool {
        const old = sink.flat;
        sink.flat = flat;
        return old;
    }
};

/// Pooled or immediate text; 30 bits.
///
/// A text is either
///
///   (1) a single-line non-empty UTF-8 string ("a slice");
///   (2) the empty text;
///   (3) the soft line break character ("␤");
///   (4) ␤ followed by a slice; or
///   (5) a slice followed by ␤.
///
/// This lets us construct `X <> nl` and `nl <> X`
/// for most text nodes without allocating a plus node.
///
/// Since ␤ (`\n`, U+000A) does not occur in normal texts,
/// we simply use that as the soft line break sentinel,
/// whether as the "ASCII sidekick" or a standalone rune.
///
/// TODO: Allow ␤ as the first or last `u7` in an ASCII quad.
pub const Text = packed struct {
    kind: enum(u1) { pool, tiny },
    data: packed union {
        /// pooled string with optional ASCII sidekick; 29 bits
        pool: packed struct {
            /// whether `char` is prefix or postfix
            side: enum(u1) { l, r } = .l,
            /// optional extra ASCII char
            char: u7 = 0,
            /// index into the string pool
            text: u21,

            pub fn emit(this: @This(), sink: *Sink) !void {
                if (this.char != 0 and this.side == .l)
                    try sink.out.writeByte(this.char);

                try sink.writeString(this.text);

                if (this.char != 0 and this.side == .r)
                    try sink.out.writeByte(this.char);
            }
        },

        /// immediate text representation; 29 bits
        tiny: packed struct {
            kind: enum(u1) { splat, ascii },
            data: packed union {
                /// variable-length splat of Unicode
                splat: packed struct {
                    kind: enum(u1) { utf8, rune },
                    data: packed union {
                        /// three-byte UTF-8 sequence repeated up to 8 times
                        utf8: packed struct {
                            reps: u3,
                            utf8: @Vector(3, u8),

                            pub fn emit(this: @This(), sink: *Sink) !void {
                                _ = this;
                                _ = sink;
                                return error.Unimplemented;
                            }
                        },

                        /// 21-bit Unicode codepoint repeated up to 63 times;
                        /// canonical empty node when zero
                        rune: packed struct {
                            reps: u6 = 0,
                            code: u21 = 0,

                            pub fn emit(this: @This(), sink: *Sink) !void {
                                if (this.reps == 0)
                                    return
                                else if (this.code == '\n') {
                                    for (0..this.reps) |_|
                                        try sink.newline();
                                } else {
                                    var buffer: [4]u8 = undefined;
                                    const n = std.unicode.utf8Encode(this.code, &buffer) catch 0;
                                    var data = [1][]const u8{buffer[0..n]};
                                    try sink.out.writeSplatAll(&data, this.reps);
                                }
                            }
                        },
                    },

                    pub fn isEmptyText(this: @This()) bool {
                        return this.kind == .rune and this.data.rune.reps == 0;
                    }

                    pub fn emit(this: @This(), sink: *Sink) !void {
                        switch (this.kind) {
                            .utf8 => try this.data.utf8.emit(sink),
                            .rune => try this.data.rune.emit(sink),
                        }
                    }
                },

                /// four ASCII bytes
                ascii: packed struct {
                    chrs: @Vector(4, u7) = @splat(0),

                    pub fn emit(this: @This(), sink: *Sink) !void {
                        for (0..4) |i| {
                            const c = this.chrs[i];
                            if (c == 0) break else try sink.out.writeByte(c);
                        }
                    }
                },
            },

            pub fn isEmptyText(this: @This()) bool {
                return this.kind == .splat and this.data.splat.isEmptyText();
            }

            pub fn emit(this: @This(), sink: *Sink) !void {
                switch (this.kind) {
                    .splat => try this.data.splat.emit(sink),
                    .ascii => try this.data.ascii.emit(sink),
                }
            }
        },
    },

    pub fn isEmptyText(this: @This()) bool {
        return this.kind == .tiny and this.data.tiny.isEmptyText();
    }

    pub fn emit(this: @This(), sink: *Sink) !void {
        switch (this.kind) {
            .pool => try this.data.pool.emit(sink),
            .tiny => try this.data.tiny.emit(sink),
        }
    }
};

/// column tweak composition; 8 bits
pub const Frob = packed struct {
    /// 1 means flatten result
    flat: u1 = 0,
    /// 1 means align result to current column
    warp: u1 = 0,
    /// apply nest(n, _) to result
    nest: u6 = 0,
};

/// binary operation handle with optional column tweak; 30 bits
pub const Oper = packed struct {
    /// column frob settings
    frob: Frob = .{},
    /// which binary operation?
    kind: enum(u1) { plus, fork },
    /// index into either plus or fork list
    what: u21,

    pub fn emit(this: @This(), sink: *Sink) !void {
        switch (this.kind) {
            .plus => {
                const saveflat = sink.flat;
                defer sink.flat = saveflat;
                sink.flat |= this.frob.flat == 1;

                const args = sink.tree.heap.plus.items[this.what];
                try args.a.emit(sink);
                try args.b.emit(sink);
            },
            .fork => return error.Unimplemented,
        }
    }
};

/// handle to either terminal or binary operation; 32 bits
pub const Node = packed struct {
    kind: enum(u1) { text, oper },
    pad1: u1 = 0, // might be useful for something...
    data: packed union {
        text: Text,
        oper: Oper,
    },

    pub fn isEmptyText(this: Node) bool {
        return this.kind == .text and this.data.text.isEmptyText();
    }

    pub fn emit(this: @This(), sink: *Sink) error{
        WriteFailed,
        Unimplemented,
    }!void {
        switch (this.kind) {
            .text => try this.data.text.emit(sink),
            .oper => try this.data.oper.emit(sink),
        }
    }

    pub fn repr(this: @This()) u32 {
        return @bitCast(this);
    }

    pub const nl: Node = .{
        .kind = .text,
        .data = .{
            .text = .{
                .kind = .tiny,
                .data = .{
                    .tiny = .{
                        .kind = .splat,
                        .data = .{
                            .splat = .{
                                .kind = .rune,
                                .data = .{
                                    .rune = .{
                                        .reps = 1,
                                        .code = '\n',
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
};

/// two node handles; 64 bits
pub const Pair = struct { a: Node, b: Node };

/// tree-in-construction; actually more like DAG
pub const Tree = struct {
    heap: struct {
        byte: std.ArrayList(u8) = .empty,
        plus: std.ArrayList(Pair) = .empty,
        fork: std.ArrayList(Pair) = .empty,
    } = .{},

    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) Tree {
        return .{ .alloc = alloc };
    }

    pub fn deinit(tree: *Tree) void {
        tree.heap.byte.deinit(tree.alloc);
        tree.heap.plus.deinit(tree.alloc);
        tree.heap.fork.deinit(tree.alloc);
    }

    pub fn show(tree: *Tree, buffer: []u8, node: Node) ![]const u8 {
        var w = std.Io.Writer.fixed(buffer);
        var sink = Sink{ .tree = tree, .out = &w };
        try node.emit(&sink);
        return sink.out.buffered();
    }

    pub fn flat(tree: *Tree, lhs: Node) !Node {
        switch (lhs.kind) {
            .text => {
                _ = tree;
                return error.Unimplemented;
            },
            .oper => {
                var new = lhs;
                new.data.oper.frob.flat = 1;
                return new;
            },
        }
    }

    pub fn plus(tree: *Tree, lhs: Node, rhs: Node) !Node {
        // TODO: the dense node representation allows shortcuts.
        //
        // When A and B are tiny texts, A + B is often also a tiny text.

        const next: u21 = @intCast(tree.heap.plus.items.len);
        try tree.heap.plus.append(tree.alloc, .{ .a = lhs, .b = rhs });
        return .{
            .kind = .oper,
            .data = .{
                .oper = .{
                    .kind = .plus,
                    .what = next,
                },
            },
        };
    }

    pub fn fork(tree: *Tree, lhs: Node, rhs: Node) !Node {
        const next: u21 = @intCast(tree.heap.fork.items.len);
        try tree.heap.fork.append(tree.alloc, .{ .a = lhs, .b = rhs });
        return .{
            .kind = .oper,
            .data = .{
                .oper = .{
                    .kind = .fork,
                    .what = next,
                },
            },
        };
    }

    pub fn text(tree: *Tree, s: [:0]const u8) !Node {
        const span = s;

        if (span.len <= 1) {
            return .{
                .kind = .text,
                .data = .{
                    .text = .{
                        .kind = .tiny,
                        .data = .{
                            .tiny = .{
                                .kind = .splat,
                                .data = .{
                                    .splat = .{
                                        .kind = .rune,
                                        .data = .{
                                            .rune = .{
                                                .reps = @intCast(span.len),
                                                .code = if (span.len == 0) 0 else span[0],
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            };
        }

        if (span.len <= 4) {
            // TODO: handle non-ASCII UTF-8 spans up to 3 bytes

            var ascii = [4]u7{ 0, 0, 0, 0 };
            for (span, 0..) |c, i| {
                ascii[i] = @intCast(c);
            }

            return .{
                .kind = .text,
                .data = .{
                    .text = .{
                        .kind = .tiny,
                        .data = .{
                            .tiny = .{
                                .kind = .ascii,
                                .data = .{
                                    .ascii = .{ .chrs = ascii },
                                },
                            },
                        },
                    },
                },
            };
        }

        const spanz = span[0 .. span.len + 1];

        const spot: u21 = @intCast(
            if (std.mem.indexOf(u8, tree.heap.byte.items, spanz)) |i|
                i
            else blk: {
                const next = tree.heap.byte.items.len;
                try tree.heap.byte.appendSlice(tree.alloc, spanz);
                break :blk next;
            },
        );

        return .{
            .kind = .text,
            .data = .{
                .text = .{
                    .kind = .pool,
                    .data = .{
                        .pool = .{ .text = spot },
                    },
                },
            },
        };
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

fn expectEmitString(tree: *Tree, text: []const u8, node: Node) !void {
    const buffer = try std.testing.allocator.alloc(u8, text.len);
    defer std.testing.allocator.free(buffer);

    try expectEqualStrings(text, try tree.show(buffer, node));
}

test "show tiny" {
    var tree = Tree.init(std.testing.allocator);

    try expectEmitString(&tree, "ABCD", try tree.text("ABCD"));
    try expectEmitString(&tree, "ABC", try tree.text("ABC"));
    try expectEmitString(&tree, "AB", try tree.text("AB"));
    try expectEmitString(&tree, "A", try tree.text("A"));
    try expectEmitString(&tree, "", try tree.text(""));
}

test "show text" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    try expectEmitString(&tree, "Hello, world!", try tree.text("Hello, world!"));
}

test "text dedup" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    const n1 = try tree.text("Hello, world!");
    const n2 = try tree.text("Hello, world!");

    try expectEqual(n1.repr(), n2.repr());
    try expectEqual(1 + "Hello, world!".len, tree.heap.byte.items.len);

    const n3 = try tree.text("Hello");
    try expect(n2.repr() != n3.repr());
    try expectEqual(1 + "Hello, world!".len + 6, tree.heap.byte.items.len);
}

test "emit plus node" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    const n1 = try tree.text("Hello,");
    const n2 = try tree.text("world!");

    try expectEmitString(
        &tree,
        "Hello,world!",
        try tree.plus(n1, n2),
    );
}

test "'a' <> nl <> 'b'" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    try expectEmitString(
        &t,
        "A\nB",
        try t.plus(
            try t.plus(try t.text("A"), .nl),
            try t.text("B"),
        ),
    );
}

test "flatten('a' <> nl <> 'b')" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    try expectEmitString(
        &t,
        "A B",
        try t.flat(
            try t.plus(
                try t.plus(try t.text("A"), .nl),
                try t.text("B"),
            ),
        ),
    );
}
