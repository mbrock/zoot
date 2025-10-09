const std = @import("std");

pub const Sink = struct {
    t: *Tree,
    w: *std.Io.Writer,
    c: u16 = 0,

    pub fn writeString(sink: @This(), what: u21) !void {
        const tail = sink.t.heap.byte.items[what..];
        const span = std.mem.sliceTo(tail, 0);
        try sink.w.writeAll(span);
    }
};

/// pooled or immediate text; 30 bits
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
                    try sink.w.writeByte(this.char);

                try sink.writeString(this.text);

                if (this.char != 0 and this.side == .r)
                    try sink.w.writeByte(this.char);
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
                                else {
                                    var buffer: [4]u8 = undefined;
                                    const n = try std.unicode.utf8Encode(this.code, &buffer);
                                    var data = [1][]const u8{buffer[0..n]};
                                    try sink.w.writeSplatAll(&data, this.reps);
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
                            if (c == 0) break else try sink.w.writeByte(c);
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
    frob: Frob,
    /// which binary operation?
    kind: enum(u1) { plus, fork },
    /// index into either plus or fork list
    what: u21,

    pub fn emit(this: @This(), sink: *Sink) !void {
        _ = this;
        _ = sink;
        return error.Unimplemented;
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

    pub fn emit(this: @This(), sink: *Sink) !void {
        switch (this.kind) {
            .text => try this.data.text.emit(sink),
            .oper => try this.data.oper.emit(sink),
        }
    }
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

    pub fn show(tree: *Tree, buffer: []u8, node: Node) ![]const u8 {
        var w = std.Io.Writer.fixed(buffer);
        var sink = Sink{ .t = tree, .w = &w };
        try node.emit(&sink);
        return sink.w.buffered();
    }

    pub fn plus(tree: *Tree, lhs: Node, rhs: Node) !Node {
        // TODO: the dense node representation allows shortcuts.
        //
        // When A and B are tiny texts, A + B is often also a tiny text.

        const next: u21 = @intCast(tree.heap.plus.items.len);
        try tree.heap.plus.items.append(tree.allocator, .{ .a = lhs, .b = rhs });
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
        try tree.heap.fork.append(tree.allocator, .{ .a = lhs, .b = rhs });
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

        const spot: u21 = @intCast(
            if (std.mem.indexOf(u8, tree.heap.byte.items, span)) |i|
                i
            else blk: {
                const next = tree.heap.byte.items.len;
                try tree.heap.byte.appendSlice(tree.alloc, span);
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

fn expectEmitString(tree: *Tree, text: []const u8, node: Node) !void {
    const buffer = try std.testing.allocator.alloc(u8, text.len);
    defer std.testing.allocator.free(buffer);

    try std.testing.expectEqualStrings(text, try tree.show(buffer, node));
}

test "show tiny" {
    var tree = Tree.init(std.testing.allocator);

    try expectEmitString(&tree, "ABCD", try tree.text("ABCD"));
    try expectEmitString(&tree, "ABC", try tree.text("ABC"));
    try expectEmitString(&tree, "AB", try tree.text("AB"));
    try expectEmitString(&tree, "A", try tree.text("A"));
    try expectEmitString(&tree, "", try tree.text(""));
}
