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

    pub fn writeString(this: *@This(), what: u21) !void {
        const tail = this.tree.byte.items[what..];
        const span = std.mem.sliceTo(tail, 0);
        try this.sink.writeAll(span);
        this.head +|= @intCast(span.len);
    }

    pub fn newline(this: *@This()) !void {
        if (this.flat) {
            try this.sink.writeByte(' ');
            this.head +|= 1;
        } else {
            try this.sink.writeByte('\n');
            try this.sink.splatByteAll(' ', this.base);
            this.head = this.base;
        }
    }
};

/// This is an `std.Io.Writer` that measures without printing,
/// allocating, or concatenating anything.  It just looks for
/// newlines, tracks the cursor column, and tallies a cost.
///
/// If you emit a node into a gist sink, you measure the layout
/// exactly as it's defined; there's no separate measuring logic
/// to get wrong; we don't multiply the number of visitor patterns
/// and inductive semantic interpretations of the myriad different
/// immediate small string paradigms and quirked-up little bitfields.
///
/// By tracking the cursor movement of the `emit` code, it computes
/// what *A Pretty Expressive Printer*, following Bernardy, calls
/// the *measure* of a choiceless document.
///
/// Looking at gists instead of emits is like looking at
/// only the pure geometry of the bounding boxes;
/// the medium is the message.
///
/// The cost parameter is a type, usually a numeric vector,
/// with base cost values for newlines and characters,
/// addition that behaves monotonically, and an order.
pub fn Gist(Cost: type) type {
    return struct {
        head: u16 = 0,
        rank: Cost.Rank,
        cost: Cost,
        sink: std.Io.Writer,

        pub fn init(buffer: []u8, cost: Cost) @This() {
            return .{
                .cost = cost,
                .rank = cost.text(0, 0),
                .sink = .{
                    .buffer = buffer,
                    .vtable = &.{
                        .drain = drain,
                        .rebase = std.Io.Writer.failingRebase,
                    },
                },
            };
        }

        pub fn eval(cost: Cost, tree: *Tree, node: Node) !Cost.Rank {
            var note: [256]u8 = undefined;
            var this = init(&note, cost);
            var work = Show{ .tree = tree, .sink = &this.sink };
            try node.emit(&work);
            try this.sink.flush();
            return this.rank;
        }

        pub fn scan(this: *@This(), data: []const u8) !void {
            for (data) |c| {
                // Since the cost plus must be homomorphic or whatever,
                // the only terminal costs we need are
                //
                //   (1) cost of `nl` and
                //   (2) cost of `text(c, 1)`
                //
                // and we can always calculate it character by character,
                // dispatching only on `nl` vs anything else.
                if (c == '\n') {
                    this.rank = this.cost.plus(this.rank, this.cost.line());
                    this.head = 0;
                } else {
                    this.rank = this.cost.plus(this.rank, this.cost.text(this.head, 1));
                    this.head += 1;
                }
            }
        }

        pub fn drain(
            w: *std.Io.Writer,
            data: []const []const u8,
            splat: usize,
        ) !usize {
            const this: *@This() = @alignCast(@fieldParentPtr("sink", w));

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
}

/// Example 3.4. in *A Pretty Expressive Printer*.
///
/// > Consider an optimality objective that minimizes the sum of overflows
/// > (the number of characters that exceed a given page width limit 𝑤 in each line),
/// > and then minimizes the height (the total number of newline characters,
/// > or equivalently, the number of lines minus one).
const F1 = struct {
    w: u16,

    pub const Rank = struct {
        /// the sum of overflows
        o: u16 = 0,
        /// the number of newlines
        h: u16 = 0,

        pub fn key(rank: Rank) u32 {
            return (@as(u32, rank.o) << 16) | rank.h;
        }
    };

    pub fn init(w: u16) F1 {
        return .{ .w = w };
    }

    pub fn line(_: @This()) Rank {
        return .{ .h = 1 };
    }

    pub fn text(this: @This(), c: u16, l: u16) Rank {
        return .{ .o = (c +| l) -| @max(this.w, c) };
    }

    pub fn plus(_: @This(), lhs: Rank, rhs: Rank) Rank {
        return .{ .h = lhs.h +| rhs.h, .o = lhs.o +| rhs.o };
    }

    pub fn wins(_: @This(), a: Rank, b: Rank) bool {
        return a.key() <= b.key();
    }
};

/// Example 3.5. in *A Pretty Expressive Printer*.
///
/// > The following cost factory targets an optimality objective
/// > that minimizes the sum of *squared* overflows over the page width limit 𝑤,
/// > and then the height. This optimality objective is an improvement
/// > over the one in Example 3.4 by discouraging overly large overflows.
/// >
/// > This is (essentially) the default cost factory that our implementation,
/// > *PrettyExpressive*, employs.
const F2 = struct {
    w: u16,

    pub const Rank = struct {
        /// the sum of squared overflows
        o: u32 = 0,
        /// the number of newlines
        h: u16 = 0,

        pub fn key(snap: Rank) u48 {
            return (snap.o << 16) | snap.h;
        }
    };

    pub fn init(w: u16) F2 {
        return .{ .w = w };
    }

    pub fn line(_: @This()) Rank {
        return .{ .h = 1 };
    }

    pub fn text(this: @This(), c: u16, l: u16) Rank {
        const w = this.w;

        const a = @max(w, c) -| w;
        const b = (c + l) -| @max(w, c);

        return .{
            .o = b * (2 * a + b),
        };
    }

    pub fn plus(_: @This(), lhs: Rank, rhs: Rank) Rank {
        return .{ .h = lhs.h +| rhs.h, .o = lhs.o +| rhs.o };
    }

    pub fn wins(_: @This(), a: Rank, b: Rank) bool {
        return a.key() <= b.key();
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
pub const Tag = enum(u3) {
    span = 0b000,
    quad = 0b001,
    trip = 0b010,
    rune = 0b011,
    cons = 0b100,
    fork = 0b101,
};

pub const Side = enum(u1) { lchr, rchr };

pub const Span = packed struct {
    tag: Tag = .span,
    side: Side = .lchr,
    char: u7 = 0,
    text: u21 = 0,

    fn emitSidekick(char: u7, show: *Show) !void {
        if (char == '\n')
            try show.newline()
        else {
            try show.sink.writeByte(char);
            show.head +|= 1;
        }
    }

    pub fn emit(this: Span, show: *Show) !void {
        if (this.char != 0 and this.side == .lchr)
            try emitSidekick(this.char, show);

        try show.writeString(this.text);

        if (this.char != 0 and this.side == .rchr)
            try emitSidekick(this.char, show);
    }
};

pub const Quad = packed struct {
    tag: Tag = .quad,
    pad: u1 = 0,
    ch0: u7 = 0,
    ch1: u7 = 0,
    ch2: u7 = 0,
    ch3: u7 = 0,

    pub fn emit(this: Quad, show: *Show) !void {
        const chars = [_]u7{ this.ch0, this.ch1, this.ch2, this.ch3 };
        for (chars) |c| {
            if (c == 0) break;
            try show.sink.writeByte(c);
            show.head +|= 1;
        }
    }
};

pub const Trip = packed struct {
    tag: Tag = .trip,
    pad: u2 = 0,
    reps: u3 = 0,
    byte0: u8 = 0,
    byte1: u8 = 0,
    byte2: u8 = 0,

    pub fn emit(this: Trip, show: *Show) !void {
        _ = this;
        _ = show;
        return error.Unimplemented;
    }
};

pub const Rune = packed struct {
    tag: Tag = .rune,
    pad: u2 = 0,
    reps: u6 = 0,
    code: u21 = 0,

    pub fn emit(this: Rune, show: *Show) !void {
        if (this.reps == 0) return;

        if (this.code == '\n') {
            for (0..this.reps) |_| try show.newline();
            return;
        }

        var buffer: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(this.code, &buffer) catch 0;
        var data = [1][]const u8{buffer[0..n]};
        try show.sink.writeSplatAll(&data, this.reps);
        show.head +|= @intCast(n * this.reps);
    }

    pub fn isEmpty(this: Rune) bool {
        return this.reps == 0;
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

pub const Oper = packed struct {
    tag: Tag = .cons,
    frob: Frob = .{},
    item: u21 = 0,

    pub fn emit(this: Oper, show: *Show) !void {
        switch (this.tag) {
            .cons => {
                const saveflat = show.flat;
                defer show.flat = saveflat;
                show.flat |= this.frob.flat == 1;

                const save_base = show.base;
                defer show.base = save_base;

                if (this.frob.warp == 1)
                    show.base = show.head;

                if (this.frob.nest != 0) {
                    const addend: u16 = @intCast(this.frob.nest);
                    const widened = @as(u32, show.base) + @as(u32, addend);
                    const limit = @as(u32, std.math.maxInt(u16));
                    show.base = @intCast(@min(widened, limit));
                }

                const args = show.tree.heap.plus.items[this.item];
                try args.a.emit(show);
                try args.b.emit(show);
            },
            .fork => return error.Unimplemented,
            else => return error.Unimplemented,
        }
    }
};

/// 32-bit handle to either terminal or operation; implicitly indexes
/// into some `Tree` aggregate.
pub const Node = packed struct {
    tag: Tag,
    payload: u29 = 0,

    pub const Form = Tag;

    pub const Look = union(Tag) {
        span: Span,
        quad: Quad,
        trip: Trip,
        rune: Rune,
        cons: Oper,
        fork: Oper,
    };

    pub const Edit = union(Tag) {
        span: *Span,
        quad: *Quad,
        trip: *Trip,
        rune: *Rune,
        cons: *Oper,
        fork: *Oper,
    };

    fn view(comptime T: type, this: Node) T {
        return @bitCast(this);
    }

    fn mut(comptime T: type, this: *Node) *T {
        return @ptrCast(@alignCast(this));
    }

    pub fn look(this: Node) Look {
        return switch (this.tag) {
            .span => .{ .span = view(Span, this) },
            .quad => .{ .quad = view(Quad, this) },
            .trip => .{ .trip = view(Trip, this) },
            .rune => .{ .rune = view(Rune, this) },
            .cons => .{ .cons = view(Oper, this) },
            .fork => .{ .fork = view(Oper, this) },
        };
    }

    pub fn edit(this: *Node) Edit {
        return switch (this.tag) {
            .span => .{ .span = mut(Span, this) },
            .quad => .{ .quad = mut(Quad, this) },
            .trip => .{ .trip = mut(Trip, this) },
            .rune => .{ .rune = mut(Rune, this) },
            .cons => .{ .cons = mut(Oper, this) },
            .fork => .{ .fork = mut(Oper, this) },
        };
    }

    pub fn isText(this: Node) bool {
        return switch (this.tag) {
            .span, .quad, .trip, .rune => true,
            else => false,
        };
    }

    pub fn isEmptyText(this: Node) bool {
        return switch (this.look()) {
            .rune => |rune| rune.isEmpty(),
            else => false,
        };
    }

    pub fn emit(this: Node, show: *Show) error{
        WriteFailed,
        Unimplemented,
    }!void {
        switch (this.look()) {
            inline else => |value| try value.emit(show),
        }
    }

    pub fn repr(this: Node) u32 {
        return @bitCast(this);
    }

    pub fn fromSpan(side: Side, char: u7, text: u21) Node {
        const span: Span = .{
            .side = side,
            .char = char,
            .text = text,
        };
        return @bitCast(span);
    }

    pub fn fromQuad(chars: [4]u7) Node {
        const quad: Quad = .{
            .ch0 = chars[0],
            .ch1 = chars[1],
            .ch2 = chars[2],
            .ch3 = chars[3],
        };
        return @bitCast(quad);
    }

    pub fn fromTrip(reps: u3, bytes: [3]u8) Node {
        const trip: Trip = .{
            .reps = reps,
            .byte0 = bytes[0],
            .byte1 = bytes[1],
            .byte2 = bytes[2],
        };
        return @bitCast(trip);
    }

    pub fn fromRune(reps: u6, code: u21) Node {
        const rune: Rune = .{
            .reps = reps,
            .code = code,
        };
        return @bitCast(rune);
    }

    pub fn fromOper(kind: Tag, frob: Frob, what: u21) Node {
        const oper: Oper = .{
            .tag = kind,
            .frob = frob,
            .item = what,
        };
        return @bitCast(oper);
    }

    pub const nl: Node = Node.fromRune(1, '\n');
};

/// two node handles; 64 bits
pub const Pair = struct { a: Node, b: Node };

/// This is the aggregate root of a pretty printing syntax tree,
/// or a document layout specification.
///
/// It is used to build such specifications out of structured data.
/// The nodes of the tree use indices into lists owned by the tree.
///
/// It is also used to rank layouts, and to actually print them.
pub const Tree = struct {
    byte: std.ArrayList(u8) = .empty,
    heap: struct {
        plus: std.ArrayList(Pair) = .empty,
        fork: std.ArrayList(Pair) = .empty,
    } = .{},

    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) Tree {
        return .{ .alloc = alloc };
    }

    pub fn deinit(tree: *Tree) void {
        tree.byte.deinit(tree.alloc);
        tree.heap.plus.deinit(tree.alloc);
        tree.heap.fork.deinit(tree.alloc);
    }

    pub fn render(tree: *Tree, buffer: []u8, node: Node) ![]const u8 {
        var w = std.Io.Writer.fixed(buffer);
        var it = Show{ .tree = tree, .sink = &w };
        try node.emit(&it);
        return it.sink.buffered();
    }

    pub fn rank(tree: *Tree, conf: anytype, node: Node) !@TypeOf(conf).Rank {
        return try Gist(@TypeOf(conf)).eval(conf, tree, node);
    }

    pub fn flat(tree: *Tree, lhs: Node) !Node {
        _ = tree;
        var new = lhs;
        switch (new.edit()) {
            .span => |span| {
                if (span.char == '\n')
                    span.char = ' ';
                return new;
            },
            .quad => return new,
            .trip => return new,
            .rune => |rune| {
                if (rune.code == '\n')
                    rune.code = ' ';
                return new;
            },
            .cons, .fork => |oper| {
                oper.frob.flat = 1;
                return new;
            },
        }
    }

    /// The `nest` combinator shifts the base of a layout's
    /// tail forward by some indent level.  The first line
    /// is not affected.
    ///
    ///      foobar(
    ///      ..xxxxx
    ///      ..xxxxx
    pub fn nest(tree: *Tree, indent: u6, doc: Node) !Node {
        _ = tree;
        if (indent == 0)
            return doc;

        var new = doc;
        switch (new.edit()) {
            .cons, .fork => |oper| {
                oper.frob.nest +|= indent;
                return new;
            },
            else => return doc,
        }
    }

    /// This is the *align* combinator.
    ///
    /// If the head is at column 3, `warp(D)` looks like:
    ///
    ///        v
    ///        DDDDDD
    ///     ...DDDDDD
    ///     ...DDD
    pub fn warp(tree: *Tree, doc: Node) !Node {
        switch (doc.tag) {
            .cons, .fork => {
                var new = doc;
                switch (new.edit()) {
                    .cons, .fork => |oper| oper.frob.warp = 1,
                    else => unreachable,
                }
                return new;
            },
            .span, .quad, .trip, .rune => if (doc.isEmptyText())
                return doc
            else {
                const oper = try tree.plus(doc, try tree.text(""));

                // We need an `oper` to carry the `frob`.
                // If `plus` learns to fuse tiny texts,
                // we'll need to fix this path.
                std.debug.assert(oper.tag == .cons);

                return try tree.warp(oper);
            },
        }
    }

    pub fn plus(tree: *Tree, lhs: Node, rhs: Node) !Node {
        if (rhs == Node.nl and lhs.isText()) {
            var new = lhs;
            switch (new.edit()) {
                .span => |span| {
                    if (span.char == 0) {
                        span.side = .rchr;
                        span.char = '\n';
                        return new;
                    }
                },
                else => {},
            }
        }

        if (lhs == Node.nl and rhs.isText()) {
            var new = rhs;
            switch (new.edit()) {
                .span => |span| {
                    if (span.char == 0) {
                        span.side = .lchr;
                        span.char = '\n';
                        return new;
                    }
                },
                else => {},
            }
        }

        // TODO: the dense node representation allows shortcuts.
        //
        // When A and B are tiny texts, A + B is often also a tiny text.

        const next: u21 = @intCast(tree.heap.plus.items.len);
        try tree.heap.plus.append(tree.alloc, .{ .a = lhs, .b = rhs });
        return Node.fromOper(.cons, .{}, next);
    }

    pub fn fork(tree: *Tree, lhs: Node, rhs: Node) !Node {
        const next: u21 = @intCast(tree.heap.fork.items.len);
        try tree.heap.fork.append(tree.alloc, .{ .a = lhs, .b = rhs });
        return Node.fromOper(.fork, .{}, next);
    }

    /// Concatenate multiple nodes in sequence
    pub fn cat(tree: *Tree, nodes: []const Node) !Node {
        if (nodes.len == 0) return try tree.text("");
        var result = nodes[0];
        for (nodes[1..]) |n| {
            result = try tree.plus(result, n);
        }
        return result;
    }

    /// Join nodes with a separator
    pub fn join(tree: *Tree, nodes: []const Node, sep: Node) !Node {
        if (nodes.len == 0) return try tree.text("");
        var result = nodes[0];
        for (nodes[1..]) |n| {
            result = try tree.plus(result, sep);
            result = try tree.plus(result, n);
        }
        return result;
    }

    /// Concatenate text strings into a single node
    pub fn str(tree: *Tree, strings: []const [:0]const u8) !Node {
        if (strings.len == 0) return try tree.text("");
        var result = try tree.text(strings[0]);
        for (strings[1..]) |s| {
            result = try tree.plus(result, try tree.text(s));
        }
        return result;
    }

    /// Add a node only if condition is true, otherwise return empty
    pub fn when(tree: *Tree, condition: bool, node: Node) !Node {
        return if (condition) node else try tree.text("");
    }

    /// Wrap body in "header {" ... "}" with optional indentation
    pub fn block(tree: *Tree, header: Node, body: Node, indent: u6) !Node {
        const open = try tree.plus(header, try tree.text(" {"));
        const indented = if (indent > 0) try tree.nest(indent, body) else body;
        const close = try tree.text("}");

        return try tree.join(&.{
            open,
            indented,
            close,
        }, Node.nl);
    }

    /// Format a string using std.fmt and add to the slab with deduplication
    pub fn format(tree: *Tree, comptime fmt: []const u8, args: anytype) !Node {
        const start_len = tree.byte.items.len;

        // Format directly into the slab
        try tree.byte.writer(tree.alloc).print(fmt ++ "\x00", args);

        // Now use text() which will do the deduplication logic for us
        const written = tree.byte.items[start_len .. tree.byte.items.len - 1 :0];
        const node = try tree.text(written);

        // If text() didn't point to our new string, rewind the slab
        // (either it found a duplicate, or it made a tiny immediate node)
        const start_index: u21 = @intCast(start_len);
        const should_rewind = switch (node.look()) {
            .span => |span| span.text != start_index,
            .quad, .trip, .rune => true,
            else => false,
        };

        if (should_rewind) {
            tree.byte.shrinkRetainingCapacity(start_len);
        }

        return node;
    }

    /// Join nodes with a separator (like sepBy in Haskell)
    pub fn sepBy(tree: *Tree, items: []const Node, sep: Node) !Node {
        return try tree.join(items, sep);
    }

    /// Wrap content in delimiters: open <> content <> close
    pub fn wrap(tree: *Tree, open: [:0]const u8, content: Node, close: [:0]const u8) !Node {
        return try tree.cat(&.{
            try tree.text(open),
            content,
            try tree.text(close),
        });
    }

    /// Wrap in parentheses: (content)
    pub fn parens(tree: *Tree, content: Node) !Node {
        return try tree.wrap("(", content, ")");
    }

    /// Wrap in brackets: [content]
    pub fn brackets(tree: *Tree, content: Node) !Node {
        return try tree.wrap("[", content, "]");
    }

    /// Wrap in braces: {content}
    pub fn braces(tree: *Tree, content: Node) !Node {
        return try tree.wrap("{", content, "}");
    }

    /// Wrap in double quotes: "content"
    pub fn quotes(tree: *Tree, content: Node) !Node {
        return try tree.wrap("\"", content, "\"");
    }

    /// Attribute pattern: name="value"
    pub fn attr(tree: *Tree, name: [:0]const u8, value: Node) !Node {
        return try tree.cat(&.{
            try tree.text(name),
            try tree.text("=\""),
            value,
            try tree.text("\""),
        });
    }

    pub fn text(tree: *Tree, s: [:0]const u8) !Node {
        const span = s;

        if (span.len <= 1) {
            const code: u21 = if (span.len == 0) 0 else @intCast(span[0]);
            return Node.fromRune(@intCast(span.len), code);
        }

        if (span.len <= 4) {
            // Check if all bytes are ASCII (< 128)
            var all_ascii = true;
            for (span) |c| {
                if (c >= 128) {
                    all_ascii = false;
                    break;
                }
            }

            if (all_ascii) {
                var ascii = [4]u7{ 0, 0, 0, 0 };
                for (span, 0..) |c, i| {
                    ascii[i] = @intCast(c);
                }

                return Node.fromQuad(ascii);
            }
            // Fall through to pool case for non-ASCII UTF-8
        }

        const spanz = span[0 .. span.len + 1];

        const spot: u21 = @intCast(
            if (std.mem.indexOf(u8, tree.byte.items, spanz)) |i|
                i
            else blk: {
                const next = tree.byte.items.len;
                try tree.byte.appendSlice(tree.alloc, spanz);
                break :blk next;
            },
        );

        return Node.fromSpan(.lchr, 0, spot);
    }

    pub fn format_peek(tree: *Tree, comptime fmt: []const u8, args: anytype) !Node.Look {
        _ = tree;
        _ = fmt;
        _ = args;
        return error.Unimplemented;
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

fn expectEmitString(tree: *Tree, text: []const u8, node: Node) !void {
    const buffer = try std.testing.allocator.alloc(u8, text.len * 2);
    defer std.testing.allocator.free(buffer);

    try expectEqualStrings(text, try tree.render(buffer, node));
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
    try expectEqual(1 + "Hello, world!".len, tree.byte.items.len);

    const n3 = try tree.text("Hello");
    try expect(n2.repr() != n3.repr());
    try expectEqual(1 + "Hello, world!".len + 6, tree.byte.items.len);
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

    try expect(fused.tag == .span);
    switch (fused.look()) {
        .span => |pool| {
            try expectEqual(pool.side, .rchr);
            try expectEqual(pool.char, '\n');
        },
        else => unreachable,
    }
    try expectEqual(0, t.heap.plus.items.len);
    try expectEmitString(&t, "Hello, world!\n", fused);
}

test "fuse nl <> text" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    const text_node = try t.text("Hello, world!");
    const fused = try t.plus(.nl, text_node);

    try expect(fused.tag == .span);
    switch (fused.look()) {
        .span => |pool| {
            try expectEqual(pool.side, .lchr);
            try expectEqual(pool.char, '\n');
        },
        else => unreachable,
    }
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

    const s1 = try t.rank(
        F1.init(32),
        try t.plus(
            try t.plus(
                try t.text("foo {"),
                try t.nest(
                    4,
                    try t.plus(.nl, try t.text("bar")),
                ),
            ),
            try t.plus(.nl, try t.text("}")),
        ),
    );

    try expectEqual(2, s1.h);
    try expectEqual(0, s1.o);
}

test "F2 cost matches example" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    // See Example 3.5. and Figure 7 in *A Pretty Expressive Printer*.

    const d1 = try t.text("   = func( pretty, print )");
    const c1 = try t.rank(F2.init(6), d1);

    try expectEqual(0, c1.h);
    try expectEqual(20 * 20, c1.o);

    const d2 = try t.plus(
        try t.nest(
            2,
            try t.plus(
                try t.plus(try t.text("   = func("), .nl),
                try t.plus(
                    try t.plus(try t.text("pretty,"), .nl),
                    try t.text("print"),
                ),
            ),
        ),
        try t.plus(.nl, try t.text(")")),
    );

    try expectEmitString(&t,
        \\   = func(
        \\  pretty,
        \\  print
        \\)
    , d2);

    const c2 = try t.rank(F2.init(6), d2);

    try expectEqual(3, c2.h);
    try expectEqual(4 * 4 + 3 * 3 + 1, c2.o);
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

test "warp aligns after NL; nest adds indent" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    // doc = "AAA" <> NL <> "B"
    const doc0 =
        try t.plus(
            try t.plus(try t.text("AAA"), Node.nl),
            try t.text("B"),
        );

    // apply warp first (align base to current column = 0), then add nest(+2)
    const doc1 = try t.warp(doc0);
    const doc2 = try t.nest(2, doc1);

    // result: "AAA\n" + 0 (warp) + 2 (nest) spaces + "B"
    try expectEmitString(&t, "AAA\n  B", doc2);
}

test "warp with nest when head is non-zero" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    // inner = "X" <> NL <> "Y"
    const inner =
        try t.plus(
            try t.plus(try t.text("X"), Node.nl),
            try t.text("Y"),
        );

    // apply warp and nest to inner
    const warped = try t.warp(inner);
    const nested = try t.nest(2, warped);

    // outer = "AAA" <> nested
    // When we emit nested, head will be at column 3 (after "AAA")
    const outer = try t.plus(try t.text("AAA"), nested);

    // result: "AAA" (head=3) + "X" (head=4) + "\n" + (3 warp + 2 nest = 5 spaces) + "Y"
    try expectEmitString(&t, "AAAX\n     Y", outer);
}
