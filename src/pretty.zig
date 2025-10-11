const std = @import("std");
const TreePrinter = @import("TreePrinter.zig");
const log = std.log;

pub const Bank = std.mem.Allocator;

/// An iterable path of binary decisions.
pub const Path = struct {
    const BitSet = std.bit_set.DynamicBitSetUnmanaged;

    bits: BitSet = .{},

    pub const none: Path = .{};

    pub fn deinit(this: *Path, alloc: Bank) void {
        this.bits.deinit(alloc);
    }

    pub fn copy(this: *const Path, alloc: Bank) !Path {
        return .{ .bits = try this.bits.clone(alloc) };
    }

    pub fn turn(this: Path, alloc: Bank, bit: u1) !Path {
        var that = try this.copy(alloc);
        try that.push(alloc, bit);
        return that;
    }

    pub fn push(this: *Path, alloc: Bank, bit: u1) !void {
        const len = this.bits.bit_length;
        try this.bits.resize(alloc, len + 1, false);
        if (bit == 1) this.bits.set(len);
    }

    pub fn walk(this: *const Path) Walk {
        return .{ .bits = this.bits };
    }

    pub fn format(this: Path, writer: *std.Io.Writer) !void {
        if (this.bits.bit_length == 0) {
            try writer.writeByte('-');
            return;
        }
        var index: usize = 0;
        while (index < this.bits.bit_length) : (index += 1) {
            const bit = this.bits.isSet(index);
            try writer.writeAll(if (bit) "╱" else "╲");
        }
    }

    /// Dense iterator over bit values
    pub const Walk = struct {
        bits: BitSet = .{},
        curr: usize = 0,

        pub fn next(this: *Walk) ?bool {
            if (this.curr >= this.bits.bit_length) return null;
            defer this.curr += 1;
            return this.bits.isSet(this.curr);
        }

        pub fn step(this: *Walk) !bool {
            return this.next() orelse error.MazePathUnderflow;
        }

        pub fn take(this: *Walk, lhs: anytype, rhs: @TypeOf(lhs)) !@TypeOf(lhs) {
            return if (try this.step()) rhs else lhs;
        }

        pub fn remaining(this: *const Walk) usize {
            return this.bits.bit_length - this.curr;
        }
    };
};

pub const Plot = struct {
    /// output writer
    sink: *std.Io.Writer,
    /// cursor column
    head: u16 = 0,
    /// indent column
    base: u16 = 0,
    /// treat ␤ as ␠?
    flat: bool = false,
    /// fork choice iterator
    path: Path.Walk = Path.none.walk(),

    pub fn writeString(this: *@This(), tree: *const Tree, what: u21) !void {
        const tail = tree.heap.text.items[what..];
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

    /// Return either `x0` or `x1` depending on the next bit in the `path`.
    /// This is used to emit the root node after resolving the best fork path.
    pub fn pick(this: *@This(), x0: anytype, x1: @TypeOf(x0)) !@TypeOf(x0) {
        return this.path.take(x0, x1);
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

        pub fn eval(cost: Cost, tree: *Tree, path: Path, node: Node) !Cost.Rank {
            var note: [256]u8 = undefined;
            var this = init(&note, cost);
            var work = Plot{
                .sink = &this.sink,
                .path = path.walk(),
            };
            try node.emit(&work, tree);
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
pub const F1 = struct {
    w: u16,

    pub const Rank = struct {
        /// the sum of overflows
        o: u16 = 0,
        /// the number of newlines
        h: u16 = 0,

        pub fn key(rank: Rank) u32 {
            return (@as(u32, rank.o) << 16) | rank.h;
        }

        pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{d: >4} debt {d: >4} rows", .{ self.o, self.h });
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
pub const F2 = struct {
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

    fn emitSidekick(char: u7, plot: *Plot) !void {
        if (char == '\n')
            try plot.newline()
        else {
            try plot.sink.writeByte(char);
            plot.head +|= 1;
        }
    }

    pub fn emit(this: Span, plot: *Plot, tree: *Tree) !void {
        if (this.char != 0 and this.side == .lchr)
            try emitSidekick(this.char, plot);

        try plot.writeString(tree, this.text);

        if (this.char != 0 and this.side == .rchr)
            try emitSidekick(this.char, plot);
    }
};

pub const Quad = packed struct {
    tag: Tag = .quad,
    pad: u1 = 0,
    ch0: u7 = 0,
    ch1: u7 = 0,
    ch2: u7 = 0,
    ch3: u7 = 0,

    pub fn emit(this: Quad, plot: *Plot, _: *Tree) !void {
        const chars = [_]u7{ this.ch0, this.ch1, this.ch2, this.ch3 };
        for (chars) |c| {
            if (c == 0) break;
            try plot.sink.writeByte(c);
            plot.head +|= 1;
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

    pub fn emit(this: Trip, plot: *Plot, _: *Tree) !void {
        _ = this;
        _ = plot;
        return error.Unimplemented;
    }
};

pub const Rune = packed struct {
    tag: Tag = .rune,
    pad: u2 = 0,
    reps: u6 = 0,
    code: u21 = 0,

    pub fn emit(this: Rune, plot: *Plot, _: *Tree) !void {
        if (this.reps == 0) return;

        if (this.code == '\n') {
            for (0..this.reps) |_| try plot.newline();
            return;
        }

        var buffer: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(this.code, &buffer) catch 0;
        var data = [1][]const u8{buffer[0..n]};
        try plot.sink.writeSplatAll(&data, this.reps);
        plot.head +|= @intCast(n * this.reps);
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
    kind: Tag = .cons,
    frob: Frob = .{},
    item: u21 = 0,

    pub fn emit(this: Oper, plot: *Plot, tree: *Tree) !void {
        switch (this.kind) {
            .cons => {
                const saveflat = plot.flat;
                defer plot.flat = saveflat;
                plot.flat |= this.frob.flat == 1;

                const save_base = plot.base;
                defer plot.base = save_base;

                if (this.frob.warp == 1)
                    plot.base = plot.head;

                if (this.frob.nest != 0) {
                    const addend: u16 = @intCast(this.frob.nest);
                    const widened = @as(u32, plot.base) + @as(u32, addend);
                    const limit = @as(u32, std.math.maxInt(u16));
                    plot.base = @intCast(@min(widened, limit));
                }

                const args = tree.heap.cons.items[this.item];
                try args.head.emit(plot, tree);
                try args.tail.emit(plot, tree);
            },
            .fork => {
                const args = tree.heap.fork.items[this.item];
                const next = try plot.pick(args.head, args.tail);
                try next.emit(plot, tree);
            },
            else => return error.Unimplemented,
        }
    }
};

/// 32-bit handle to either terminal or operation; implicitly indexes
/// into some `Tree` aggregate.
pub const Node = packed struct {
    tag: Tag,
    data: u29 = 0,

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

    pub const halt = Node.fromRune(0, 0);

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

    pub fn load(this: Node, heap: *const Heap) Pair {
        return switch (this.look()) {
            .cons => |cons| heap.cons.items[cons.item],
            .fork => |fork| heap.fork.items[fork.item],
            else => unreachable,
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

    pub fn isTerminal(this: Node) bool {
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

    pub fn emit(this: Node, plot: *Plot, tree: *Tree) error{
        WriteFailed,
        Unimplemented,
        MazePathUnderflow,
    }!void {
        switch (this.look()) {
            inline else => |value| try value.emit(plot, tree),
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
            .kind = kind,
            .frob = frob,
            .item = what,
        };
        return @bitCast(oper);
    }

    pub const nl: Node = Node.fromRune(1, '\n');
};

pub const Pair = packed struct {
    head: Node,
    tail: Node,

    pub const halt: Pair = just(.halt);

    pub fn just(a: Node) Pair {
        return .{ .head = a, .tail = .halt };
    }
};

pub const Task = packed struct {
    expr: Node,
    link: Link = .halt,

    pub const Link = packed struct {
        kind: enum(u1) { link, pink },
        item: u21,

        pub const halt: Link = .{
            .kind = .link,
            .item = std.math.maxInt(u21),
        };

        pub fn load(this: @This(), heap: *const Heap) Task {
            if (this == Link.halt)
                return Task.halt;
            return heap.work.list.items[this.item];
        }
    };

    pub const Slot = u21;

    pub fn into(slot: Slot) Link {
        return .{ .kind = .link, .item = slot };
    }

    pub fn eval(expr: Node) Task {
        return .{ .expr = expr };
    }

    pub const halt: Task = .{ .expr = .halt };
};

pub const Step = union(enum) {
    exec: Task,
    fork: [2]Task,
    halt: void,

    pub fn just(step: Task) Step {
        return both(step, Task.halt);
    }

    pub fn both(head: Task, tail: Task) Step {
        return if (head == Task.halt)
            .{ .halt = {} }
        else if (tail == Task.halt)
            .{ .exec = head }
        else
            .{ .fork = [2]Task{ head, tail } };
    }

    /// To execute the task `e ; k` is to evaluate `e` and then execute `k`.
    ///
    /// The *flap* function defines the expansion of a task into a step
    /// with subtasks for subexpressions, linked correctly to the shared
    /// continuation task.  Like a debugger's single step operation.
    ///
    /// For simple expressions, `flap(e ; k)` is just `e ; k`.
    ///
    /// For concat, `flap((a + b) ; k)` is `a ; (b ; k)`.
    ///
    /// For choice, `flap((a | b) ; k)` is `(a ; k) & (b ; k)`.
    ///
    /// Completely applying this expansion to a syntax tree is known as
    /// the *continuation-passing style transformation*, or CPS transform.
    ///
    /// Such an expansion has no nested expressions in the usual sense.
    /// In the absence of forking choice, it linearizes expressions into
    /// sequential chains of terminals in the order of actual evaluation.
    /// In the presence of forking choice, rather than a linear task chain,
    /// we get a directed acyclic graph of tasks.
    ///
    /// This clarifies what it means to have a forking choice nested within
    /// a more complex expression.  The part of the expression evaluated
    /// before the fork becomes a sequential prefix in the graph, which
    /// then splits into two child tasks and eventually merges again;
    /// for example
    ///
    ///     a + b + ((c + d) | (e + f)) + g + h
    ///
    /// becomes the task graph
    ///
    ///           c → d
    ///          ↗     ↘
    ///     a → b        g → h ⇥ ⊤
    ///          ↘     ↗
    ///           e → f
    ///
    /// where `⊤` is the exit task.  Note that an expression always
    /// expands to a task graph with a single entry and single exit;
    /// a document full of choice denotes a single coherent element
    /// in the relevant model of evaluation.
    ///
    /// This program does `flap` as it evaluates instead of up front.
    /// Doing it up front is probably better.  That's why compilers
    /// transform into CPS or SSA; with explicit execution graphs,
    /// it's easier to optimize the execution.
    ///
    /// One optimization of the execution graph that seems relevant
    /// for this library is compacting the node structure so that
    /// linear chains are sorted contiguously in memory and stored
    /// as slices.  This is basically like compiling the document
    /// program into a graph of basic blocks.
    ///
    /// This whole way of thinking can transform the algebraic,
    /// functional, denotational semantics of the PDF papers
    /// into an operational semantics, a small-step execution
    /// engine, an abstract machine.
    ///
    /// The classic strategy, formalized by Danvy and Filinski
    /// in the 1990s but rooted in lore and practice going back
    /// at least to Gordon Plotkin in the 1970s, goes like this.
    ///
    /// You start with some beautiful denotational semantic
    /// function of an algebraic syntax type, a function from
    /// syntax to value that concisely defines the *meaning*
    /// of any valid expression, like
    ///
    ///     eval(x)            = x
    ///     eval(Plus(e1, e2)) = eval(e1) + eval(e2)
    ///
    /// or
    ///
    ///     emit(s)            = s
    ///     emit(Cons(e1, e2)) = append(emit(e1), emit(e2))
    ///
    /// or what have you.  This is your basis for equational
    /// reasoning, proving various things, sanity checking
    /// different properties, and so on.
    ///
    /// Of course you can directly implement such functions.
    /// In fact that is one of the more useful definitions of
    /// what it even means to practice *functional programming*:
    /// it's writing programs as pure functions from inductive
    /// syntactic domains into semantic models.
    ///
    /// Haskell is basically designed to let academics transcribe
    /// interesting ACM Functional Pearl papers into source code
    /// that GHC turns into remarkably adequate machine code.
    ///
    /// One thing Haskell does to enable that is lazy evaluation.
    /// Beautiful semantic functions transcribed to code, without
    /// any low level mechanics, can skip entire subcomputations
    /// which turn out to be unneeded for the final result,
    /// and functions that look like they duplicate computation
    /// can execute as clever shared mutable thunk graphs.
    ///
    /// Of course the most fundamental language feature that allows
    /// this kind of thing is just garbage collection. The semantic
    /// equations are blissfully oblivious of allocators, stack and heap,
    /// cache lines, pointer invalidation, etc, for the basic reason
    /// that they are *completely unrelated to computers*.
    ///
    /// Letting any aspect of your concrete computing machine taint
    /// your denotational semantics is like trying to define the
    /// meaning of a quadratic polynomial in terms of the Super Nintendo
    /// math coprocessor; it's not just bad style, it makes no sense.
    ///
    /// But fundamentally what a language like Haskell promises is
    /// to faithfully and elegantly preserve the functional *meaning*
    /// of the equational definitions you write down as code.  This
    /// brackets out the question of what the actual computer is doing,
    /// and how we can make it stop doing that.
    ///
    ///
    pub fn flap(heap: *Heap, bank: Bank, task: Task) !Step {
        switch (task.expr.look()) {
            .cons => |cons| {
                // To step into `a <> b` with a continuation `c`,
                // we step into `a` with a new continuation `b <> c`.
                const pair = heap.cons.items[cons.item];
                return .just(
                    .{
                        .expr = pair.head,
                        .link = try heap.work.push(bank, .{
                            .expr = pair.tail,
                            .link = task.link,
                        }),
                    },
                );
            },
            .fork => |fork| {
                const pair = heap.fork.items[fork.item];
                return .both(
                    .{ .expr = pair.head, .link = task.link },
                    .{ .expr = pair.tail, .link = task.link },
                );
            },
            else => return .just(task),
        }
    }
};

/// A *road* is one task in the maze walk.
pub const Road = struct {
    /// The path taken; the prefix of actuality.
    past: Path = .{},
    /// The road ahead; the suffix of potential.
    plan: Task,

    fn init(plan: Task) @This() {
        return .{ .plan = plan };
    }

    fn copy(self: *const @This(), bank: Bank) !@This() {
        return .{
            .past = try self.past.copy(bank),
            .plan = self.plan,
        };
    }

    fn free(self: *@This(), bank: Bank) void {
        self.past.deinit(bank);
    }
};

pub const Maze = struct {
    pub fn best(
        tree: *Tree,
        bank: Bank,
        conf: anytype,
        root: Node,
        info: ?*std.Io.Writer,
    ) !Path {
        const Rank = @TypeOf(conf).Rank;

        var path: ?Path = null;
        var peak: ?Rank = null;
        var work: std.ArrayList(Road) = .empty;

        defer work.deinit(bank);
        defer for (work.items) |*c| c.free(bank);
        errdefer if (path) |*p| p.deinit(bank);

        try work.append(bank, .init(.eval(root)));

        while (work.pop()) |task| {
            var road = task;
            defer road.free(bank);

            while (true) {
                switch (try tree.flap(road.plan)) {
                    .halt => break,
                    .exec => |plan| {
                        // Choiceless step.
                        road.plan = if (plan.expr.isTerminal())
                            // No subexpressions; jump to continuation.
                            plan.link.load(&tree.heap)
                        else
                            // Nonterminal operator.
                            plan;
                    },
                    .fork => |ways| {
                        // Branching step; enqueue the road not taken.
                        try work.append(bank, .{
                            .past = try road.past.turn(bank, 1),
                            .plan = ways[1],
                        });

                        try road.past.push(bank, 0);
                        road.plan = ways[0];
                    },
                }
            }

            // This road is fully explored; rank it and move on.

            const rank = try tree.rank(conf, road.past, root);
            const hype = peak == null or conf.wins(rank, peak.?);

            if (info) |w| {
                try w.print(
                    "{s} {f} {f}  {d: >4} maze\n",
                    .{
                        if (hype) "★" else " ",
                        road.past,
                        rank,
                        tree.heap.work.size(),
                    },
                );
            }

            if (hype) {
                if (path) |*p| p.deinit(bank);
                path = try road.past.copy(bank);
                peak = rank;
            }
        }

        return path orelse return error.MazeNoLayouts;
    }
};

pub fn List(Elem: type) type {
    return struct {
        list: std.ArrayList(Elem) = .empty,

        pub const empty: @This() = .{};

        pub fn deinit(this: *@This(), bank: Bank) void {
            this.list.deinit(bank);
        }

        pub fn push(this: *@This(), bank: Bank, elem: Elem) !Elem.Link {
            if (std.math.cast(Elem.Slot, this.list.items.len)) |slot| {
                try this.list.append(bank, elem);
                return Elem.into(slot);
            } else {
                return error.ListFull;
            }
        }

        pub fn size(this: *const @This()) Elem.Slot {
            return @intCast(this.list.items.len);
        }
    };
}

pub const Heap = struct {
    text: std.ArrayList(u8) = .empty,
    cons: std.ArrayList(Pair) = .empty,
    fork: std.ArrayList(Pair) = .empty,
    work: List(Task) = .empty,

    pub fn deinit(this: *@This(), alloc: Bank) void {
        this.text.deinit(alloc);
        this.cons.deinit(alloc);
        this.fork.deinit(alloc);
        this.work.deinit(alloc);
    }
};

/// This is the aggregate root of a pretty printing syntax tree,
/// or a document layout specification.
///
/// It is used to build such specifications out of structured data.
/// The nodes of the tree use indices into lists owned by the tree.
///
/// It is also used to rank layouts, and to actually print them.
pub const Tree = struct {
    bank: Bank,
    heap: Heap = .{},

    pub fn init(alloc: Bank) Tree {
        return .{ .bank = alloc };
    }

    pub fn deinit(tree: *Tree) void {
        tree.heap.deinit(tree.bank);
    }

    pub fn render(tree: *Tree, buffer: []u8, node: Node) ![]const u8 {
        var w = std.Io.Writer.fixed(buffer);
        var it = Plot{ .sink = &w };
        try node.emit(&it, tree);
        return it.sink.buffered();
    }

    pub fn flap(tree: *Tree, road: Task) !Step {
        return try Step.flap(&tree.heap, tree.bank, road);
    }

    pub fn emit(tree: *Tree, sink: *std.Io.Writer, node: Node) !void {
        var it = Plot{ .sink = sink };
        try node.emit(&it, tree);
    }

    pub fn rank(
        tree: *Tree,
        conf: anytype,
        path: Path,
        node: Node,
    ) !@TypeOf(conf).Rank {
        return try Gist(@TypeOf(conf)).eval(conf, tree, path, node);
    }

    pub fn best(
        tree: *Tree,
        bank: Bank,
        conf: anytype,
        node: Node,
        info: ?*std.Io.Writer,
    ) !Path {
        return Maze.best(tree, bank, conf, node, info);
    }

    pub fn renderWithPath(
        tree: *Tree,
        sink: *std.Io.Writer,
        node: Node,
        path: *const Path,
    ) !void {
        var plot = Plot{
            .sink = sink,
            .path = path.walk(),
        };
        try node.emit(&plot, tree);
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
            .work => return new,
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
            .work => return doc,
        }
    }

    pub fn plus(tree: *Tree, lhs: Node, rhs: Node) !Node {
        if (rhs == Node.nl and lhs.isTerminal()) {
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

        if (lhs == Node.nl and rhs.isTerminal()) {
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

        const next: u21 = @intCast(tree.heap.cons.items.len);
        try tree.heap.cons.append(tree.bank, .{ .head = lhs, .tail = rhs });
        return Node.fromOper(.cons, .{}, next);
    }

    pub fn fork(tree: *Tree, lhs: Node, rhs: Node) !Node {
        const next: u21 = @intCast(tree.heap.fork.items.len);
        try tree.heap.fork.append(tree.bank, .{ .head = lhs, .tail = rhs });
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

    /// Concatenate with nl separator
    pub fn pile(tree: *Tree, nodes: []const Node) !Node {
        return tree.sepBy(nodes, .nl);
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
        const start_len = tree.heap.text.items.len;

        // Format directly into the slab
        try tree.heap.text.writer(tree.bank).print(fmt ++ "\x00", args);

        // Now use text() which will do the deduplication logic for us
        const written = tree.heap.text.items[start_len .. tree.heap.text.items.len - 1 :0];
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
            tree.heap.text.shrinkRetainingCapacity(start_len);
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

    /// Separate by `", "`.
    pub fn commatize(tree: *Tree, nodes: []const Node) !Node {
        return tree.sepBy(nodes, try tree.text(", "));
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
            if (std.mem.indexOf(u8, tree.heap.text.items, spanz)) |i|
                i
            else blk: {
                const next = tree.heap.text.items.len;
                try tree.heap.text.appendSlice(tree.bank, spanz);
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
    try expectEqual(1 + "Hello, world!".len, tree.heap.text.items.len);

    const n3 = try tree.text("Hello");
    try expect(n2.repr() != n3.repr());
    try expectEqual(1 + "Hello, world!".len + 6, tree.heap.text.items.len);
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
    try expectEqual(0, t.heap.cons.items.len);
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
    try expectEqual(0, t.heap.cons.items.len);
    try expectEmitString(&t, "\nHello, world!", fused);
}

test "maze small-step plus" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    const left = try tree.text("A");
    const right = try tree.text("B");
    const doc = try tree.plus(left, right);

    const start: Pair = .{ .head = doc, .tail = .halt };
    const first = try tree.flap(start);
    const emit = first.exec;

    try expectEqual(left.repr(), emit.head.repr());
    try expect(emit.tail != Node.halt);

    const second = try tree.flap(emit.tail.load(&tree.heap));
    const again = second.exec;

    try expectEqual(right.repr(), again.head.repr());
    try expect(again.tail == Node.halt);
    try expect(again.tail.load(&tree.heap) == Pair.halt);
}

test "maze evaluation chooses best layout" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    const inline_doc = try tree.cat(&.{
        try tree.text("foo"),
        try tree.text(" "),
        try tree.text("bar"),
    });

    const multiline = try tree.cat(&.{
        try tree.text("foo"),
        Node.nl,
        try tree.text("bar"),
    });

    const doc = try tree.fork(inline_doc, multiline);

    const cost = F1.init(10);
    var result = try tree.best(std.testing.allocator, cost, doc, null);
    defer result.deinit(std.testing.allocator);

    const buf = try std.testing.allocator.alloc(u8, 64);
    defer std.testing.allocator.free(buf);
    var sink = std.Io.Writer.fixed(buf);
    try tree.renderWithPath(&sink, doc, &result);
    try expectEqualStrings("foo bar", sink.buffered());
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
        .none,
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
    const c1 = try t.rank(F2.init(6), .none, d1);

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

    const c2 = try t.rank(F2.init(6), .none, d2);

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
