const std = @import("std");

pub const Show = struct {
    tree: *Tree,
    sink: *std.Io.Writer,

    /// current column
    head: u16 = 0,
    /// indent column
    base: u16 = 0,
    /// treat ␤ as ␠?
    flat: bool = false,

    pub fn writeString(this: @This(), what: u21) !void {
        const tail = this.tree.heap.byte.items[what..];
        const span = std.mem.sliceTo(tail, 0);
        try this.sink.writeAll(span);
    }

    pub fn newline(this: *@This()) !void {
        if (this.flat)
            try this.sink.writeByte(' ')
        else {
            try this.sink.writeByte('\n');
            try this.sink.splatByteAll(' ', this.base);
        }
    }

    /// This is an `std.Io.Writer` that measures without printing.
    pub const Cost = struct {
        pub const Data = struct {
            /// total number of rows
            rows: u16 = 0,
            /// width of longest row
            long: u8 = 0,
            /// width of last row
            last: u8 = 0,
            /// overflow quantity
            debt: u8 = 0,
            /// number of newlines softened
            soft: u8 = 0,
        };

        /// accumulated cost vector
        data: Data = .{},

        /// buffered interface
        sink: std.Io.Writer,

        /// page width, or target line width
        page: u8,

        pub fn init(buffer: []u8, width: u8) Cost {
            return .{
                .page = width,
                .sink = .{
                    .buffer = buffer,
                    .vtable = &.{
                        .drain = Cost.drain,
                        .rebase = std.Io.Writer.failingRebase,
                    },
                },
            };
        }

        pub fn scan(this: *@This(), data: []const u8) !void {
            var m = &this.data;
            if (m.rows == 0) m.rows = 1;

            var head = m.last;
            var long = m.long;

            for (data) |c| {
                if (c == '\n') {
                    if (head > long) long = head;
                    m.rows += 1;
                    head = 0; // indent will be space-splatted
                } else {
                    head += 1;
                }
            }

            m.last = head;
            m.long = @max(long, head);
            if (m.long > this.page)
                m.debt = m.long - this.page;
        }

        pub fn drain(
            w: *std.Io.Writer,
            data: []const []const u8,
            splat: usize,
        ) !usize {
            const this: *Cost = @alignCast(@fieldParentPtr("sink", w));

            if (w.end > 0) {
                try this.scan(w.buffered());
                w.end = 0;
            }

            if (data.len == 0) return 0;

            var took: usize = 0;

            for (data[0 .. data.len - 1]) |part| {
                try this.scan(part);
                took += part.len;
            }

            const bulk = data[data.len - 1];
            for (0..splat) |_| {
                try this.scan(bulk);
                took += bulk.len;
            }

            return took;
        }
    };
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

            fn emitSidekick(char: u7, show: *Show) !void {
                if (char == '\n')
                    try show.newline()
                else
                    try show.sink.writeByte(char);
            }

            pub fn emit(this: @This(), show: *Show) !void {
                if (this.char != 0 and this.side == .l)
                    try emitSidekick(this.char, show);

                try show.writeString(this.text);

                if (this.char != 0 and this.side == .r)
                    try emitSidekick(this.char, show);
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

                            pub fn emit(this: @This(), show: *Show) !void {
                                _ = this;
                                _ = show;
                                return error.Unimplemented;
                            }
                        },

                        /// 21-bit Unicode codepoint repeated up to 63 times;
                        /// canonical empty node when zero
                        rune: packed struct {
                            reps: u6 = 0,
                            code: u21 = 0,

                            pub fn emit(this: @This(), show: *Show) !void {
                                if (this.reps == 0)
                                    return
                                else if (this.code == '\n') {
                                    for (0..this.reps) |_|
                                        try show.newline();
                                } else {
                                    var buffer: [4]u8 = undefined;
                                    const n = std.unicode.utf8Encode(this.code, &buffer) catch 0;
                                    var data = [1][]const u8{buffer[0..n]};
                                    try show.sink.writeSplatAll(&data, this.reps);
                                }
                            }
                        },
                    },

                    pub fn isEmptyText(this: @This()) bool {
                        return this.kind == .rune and this.data.rune.reps == 0;
                    }

                    pub fn emit(this: @This(), show: *Show) !void {
                        switch (this.kind) {
                            .utf8 => try this.data.utf8.emit(show),
                            .rune => try this.data.rune.emit(show),
                        }
                    }
                },

                /// four ASCII bytes
                ascii: packed struct {
                    chrs: @Vector(4, u7) = @splat(0),

                    pub fn emit(this: @This(), show: *Show) !void {
                        for (0..4) |i| {
                            const c = this.chrs[i];
                            if (c == 0) break else try show.sink.writeByte(c);
                        }
                    }
                },
            },

            pub fn isEmptyText(this: @This()) bool {
                return this.kind == .splat and this.data.splat.isEmptyText();
            }

            pub fn emit(this: @This(), show: *Show) !void {
                switch (this.kind) {
                    .splat => try this.data.splat.emit(show),
                    .ascii => try this.data.ascii.emit(show),
                }
            }
        },
    },

    pub fn isEmptyText(this: @This()) bool {
        return this.kind == .tiny and this.data.tiny.isEmptyText();
    }

    pub fn emit(this: @This(), show: *Show) !void {
        switch (this.kind) {
            .pool => try this.data.pool.emit(show),
            .tiny => try this.data.tiny.emit(show),
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

    pub fn emit(this: @This(), show: *Show) !void {
        switch (this.kind) {
            .plus => {
                const saveflat = show.flat;
                defer show.flat = saveflat;
                show.flat |= this.frob.flat == 1;

                const save_base = show.base;
                defer show.base = save_base;
                if (this.frob.nest != 0) {
                    const addend: u16 = @intCast(this.frob.nest);
                    const widened = @as(u32, save_base) + @as(u32, addend);
                    const limit = @as(u32, std.math.maxInt(u16));
                    show.base = @intCast(@min(widened, limit));
                }

                const args = show.tree.heap.plus.items[this.what];
                try args.a.emit(show);
                try args.b.emit(show);
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

    pub fn emit(this: @This(), show: *Show) error{
        WriteFailed,
        Unimplemented,
    }!void {
        switch (this.kind) {
            .text => try this.data.text.emit(show),
            .oper => try this.data.oper.emit(show),
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
        var it = Show{ .tree = tree, .sink = &w };
        try node.emit(&it);
        return it.sink.buffered();
    }

    pub fn cost(tree: *Tree, page: u8, node: Node) !Show.Cost.Data {
        var note: [256]u8 = undefined;
        var sink = Show.Cost.init(&note, page);
        var work = Show{ .tree = tree, .sink = &sink.sink };
        try node.emit(&work);
        try sink.sink.flush();
        return sink.data;
    }

    pub fn flat(tree: *Tree, lhs: Node) !Node {
        _ = tree;
        switch (lhs.kind) {
            .text => {
                var new = lhs;
                switch (new.data.text.kind) {
                    .pool => {
                        var pooled = &new.data.text.data.pool;
                        if (pooled.char == '\n')
                            pooled.char = @as(u7, ' ');
                    },
                    .tiny => {
                        var tiny = &new.data.text.data.tiny;
                        switch (tiny.kind) {
                            .splat => {
                                var splat = &tiny.data.splat;
                                switch (splat.kind) {
                                    .utf8 => {},
                                    .rune => {
                                        if (splat.data.rune.code == '\n')
                                            splat.data.rune.code = ' ';
                                    },
                                }
                            },
                            .ascii => {},
                        }
                    },
                }
                return new;
            },
            .oper => {
                var new = lhs;
                new.data.oper.frob.flat = 1;
                return new;
            },
        }
    }

    pub fn nest(tree: *Tree, indent: u6, doc: Node) !Node {
        _ = tree;
        if (indent == 0)
            return doc;

        switch (doc.kind) {
            .text => return doc,
            .oper => {
                var new = doc;
                const limit: u16 = std.math.maxInt(u6);
                const sum = @as(u16, new.data.oper.frob.nest) + @as(u16, indent);
                const clamped: u6 = @intCast(if (sum > limit) limit else sum);
                new.data.oper.frob.nest = clamped;
                return new;
            },
        }
    }

    pub fn plus(tree: *Tree, lhs: Node, rhs: Node) !Node {
        const nl_repr = Node.nl.repr();

        if (rhs.repr() == nl_repr and lhs.kind == .text) {
            var fused = lhs;
            if (fused.data.text.kind == .pool) {
                var pool = &fused.data.text.data.pool;
                if (pool.char == 0) {
                    pool.side = .r;
                    pool.char = '\n';
                    return fused;
                }
            }
        }

        if (lhs.repr() == nl_repr and rhs.kind == .text) {
            var fused = rhs;
            if (fused.data.text.kind == .pool) {
                var pool = &fused.data.text.data.pool;
                if (pool.char == 0) {
                    pool.side = .l;
                    pool.char = '\n';
                    return fused;
                }
            }
        }

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

test "fuse text <> nl" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    const text_node = try t.text("Hello, world!");
    const fused = try t.plus(text_node, .nl);

    try expect(fused.kind == .text);
    const pool = fused.data.text.data.pool;
    try expectEqual(pool.side, .r);
    try expectEqual(pool.char, '\n');
    try expectEqual(0, t.heap.plus.items.len);
    try expectEmitString(&t, "Hello, world!\n", fused);
}

test "fuse nl <> text" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    const text_node = try t.text("Hello, world!");
    const fused = try t.plus(.nl, text_node);

    try expect(fused.kind == .text);
    const pool = fused.data.text.data.pool;
    try expectEqual(pool.side, .l);
    try expectEqual(pool.char, '\n');
    try expectEqual(0, t.heap.plus.items.len);
    try expectEmitString(&t, "\nHello, world!", fused);
}

test "flatten fused text <> nl" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    const fused = try t.plus(try t.text("A"), .nl);
    try expectEmitString(&t, "A ", try t.flat(fused));
}

test "nest braces emit" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    const doc = try t.plus(
        try t.plus(
            try t.text("foo {"),
            try t.nest(
                4,
                try t.plus(.nl, try t.text("bar")),
            ),
        ),
        try t.plus(.nl, try t.text("}")),
    );

    try expectEmitString(&t,
        \\foo {
        \\    bar
        \\}
    , doc);
}

test "nest braces cost" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    const doc = try t.plus(
        try t.plus(
            try t.text("foo {"),
            try t.nest(
                4,
                try t.plus(.nl, try t.text("bar")),
            ),
        ),
        try t.plus(.nl, try t.text("}")),
    );

    const m: Show.Cost.Data = try t.cost(32, doc);
    try expectEqual(3, m.rows);
    try expectEqual(1, m.last);
    try expectEqual(7, m.long);
    try expectEqual(0, m.debt);
    try expectEqual(0, m.soft);
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
