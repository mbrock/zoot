const std = @import("std");
const TreePrinter = @import("TreePrinter.zig");
const log = std.log;

pub const Bank = std.mem.Allocator;

pub const Crux = struct {
    head: u16 = 0,
    base: u16 = 0,
    rows: u16 = 0,
    icky: bool = false,

    pub fn warp(self: *@This()) void {
        self.base = self.head;
    }

    pub fn nest(self: *@This(), indent: u6) void {
        if (indent == 0) return;
        const widened = @as(u32, self.base) + @as(u32, indent);
        const limit = @as(u32, std.math.maxInt(u16));
        self.base = @intCast(@min(widened, limit));
    }
};

/// Cost factory vtable for runtime polymorphism over different cost metrics.
/// All ranks are now standardized to u64.
pub const CostFactory = struct {
    ptr: *const anyopaque,
    plusFn: *const fn (ptr: *const anyopaque, lhs: u64, rhs: u64) u64,
    lineFn: *const fn (ptr: *const anyopaque) u64,
    textFn: *const fn (ptr: *const anyopaque, c: u16, l: u16) u64,
    winsFn: *const fn (ptr: *const anyopaque, a: u64, b: u64) bool,
    taintedFn: *const fn (ptr: *const anyopaque, rank: u64) bool,

    pub fn plus(self: CostFactory, lhs: u64, rhs: u64) u64 {
        return self.plusFn(self.ptr, lhs, rhs);
    }

    pub fn line(self: CostFactory) u64 {
        return self.lineFn(self.ptr);
    }

    pub fn text(self: CostFactory, c: u16, l: u16) u64 {
        return self.textFn(self.ptr, c, l);
    }

    pub fn wins(self: CostFactory, a: u64, b: u64) bool {
        return self.winsFn(self.ptr, a, b);
    }

    pub fn tainted(self: CostFactory, rank: u64) bool {
        return self.taintedFn(self.ptr, rank);
    }
};

pub const Idea = struct {
    last: u16 = 0,
    rows: u16 = 0,
    icky: bool = false,
    node: Node = Node.halt,
    rank: u64 = 0,
};

pub const MachineStats = struct {
    memo_hits: usize = 0,
    memo_misses: usize = 0,
};

pub const BestOutcome = struct {
    measure: Idea,
    completions: usize = 0,
    memo_hits: usize = 0,
    memo_misses: usize = 0,
    memo_entries: usize = 0,
    frontier_non_tainted: usize = 0,
    tainted_kept: bool = false,
    queue_peak: usize = 0,
};

pub const MemoKey = packed struct {
    node: u32,
    head: u16,
    base: u16,
};

pub const Memo = std.AutoHashMap(MemoKey, Idea);

pub const Kont = union(enum) {
    done,
    after_left: AfterLeft,
    after_right: AfterRight,

    const Self = @This();

    pub const AfterLeft = struct {
        node: Node,
        rhs: Node,
        right_base: u16,
        head: u16,
        base: u16,
        next: *Self,
    };

    pub const AfterRight = struct {
        node: Node,
        head: u16,
        base: u16,
        left: Idea,
        next: *Self,
    };
};

pub const Exec = union(enum) {
    eval: struct {
        node: Node,
        crux: Crux,
        then: *Kont,
    },
    fork: struct {
        left: struct {
            node: Node,
            crux: Crux,
            then: *Kont,
        },
        right: struct {
            node: Node,
            crux: Crux,
            then: *Kont,
        },
    },
    give: struct {
        idea: Idea,
        then: *Kont,
    },
    done: struct {
        idea: Idea,
    },
};

pub fn machineStep(
    tree: *Tree,
    cf: CostFactory,
    work: *List(Kont),
    exec: *Exec,
    memo: ?*Memo,
    stats: ?*MachineStats,
) !void {
    switch (exec.*) {
        .eval => |eval| {
            const key = MemoKey{
                .node = eval.node.repr(),
                .head = eval.crux.head,
                .base = eval.crux.base,
            };

            if (memo) |m| {
                if (m.get(key)) |idea| {
                    if (stats) |s| s.memo_hits += 1;
                    exec.* = .{
                        .give = .{
                            .idea = idea,
                            .then = eval.then,
                        },
                    };
                    return;
                }
            }
            if (stats) |s| s.memo_misses += 1;

            switch (eval.node.look()) {
                .rune => |rune| {
                    var last = eval.crux.head;
                    var rows: u16 = 0;
                    var rank: u64 = 0;

                    if (rune.reps != 0) {
                        if (rune.code == '\n') {
                            rows = rune.reps;
                            last = eval.crux.base;
                            for (0..rune.reps) |_| {
                                rank = cf.plus(rank, cf.line());
                            }
                        } else {
                            const width_per = std.unicode.utf8CodepointSequenceLength(rune.code) catch 1;
                            const total: u32 = @intCast(@as(u32, width_per) * rune.reps);
                            rank = cf.plus(rank, cf.text(eval.crux.head, @intCast(total)));
                            const widened = @as(u32, eval.crux.head) + total;
                            const limit = @as(u32, std.math.maxInt(u16));
                            last = @intCast(@min(widened, limit));
                        }
                    }

                    const idea = Idea{
                        .node = eval.node,
                        .last = last,
                        .rows = rows,
                        .rank = rank,
                        .icky = cf.tainted(rank),
                    };

                    if (memo) |m| try m.put(key, idea);
                    exec.* = .{
                        .give = .{
                            .idea = idea,
                            .then = eval.then,
                        },
                    };
                },
                .span => |span| {
                    var head = eval.crux.head;
                    var rows: u16 = 0;
                    var rank: u64 = 0;

                    if (span.char != 0 and span.side == .lchr) {
                        if (span.char == '\n') {
                            rows +|= 1;
                            head = eval.crux.base;
                            rank = cf.plus(rank, cf.line());
                        } else {
                            rank = cf.plus(rank, cf.text(head, 1));
                            head +|= 1;
                        }
                    }

                    const tail = tree.heap.text.items[span.text..];
                    const text = std.mem.sliceTo(tail, 0);
                    const text_len: u16 = @intCast(text.len);
                    if (text_len != 0) {
                        rank = cf.plus(rank, cf.text(head, text_len));
                        head +|= text_len;
                    }

                    if (span.char != 0 and span.side == .rchr) {
                        if (span.char == '\n') {
                            rows +|= 1;
                            rank = cf.plus(rank, cf.line());
                            head = eval.crux.base;
                        } else {
                            rank = cf.plus(rank, cf.text(head, 1));
                            head +|= 1;
                        }
                    }

                    const idea = Idea{
                        .node = eval.node,
                        .last = head,
                        .rows = rows,
                        .rank = rank,
                        .icky = cf.tainted(rank),
                    };

                    if (memo) |m| try m.put(key, idea);
                    exec.* = .{
                        .give = .{
                            .idea = idea,
                            .then = eval.then,
                        },
                    };
                },
                .quad => |quad| {
                    var head = eval.crux.head;
                    var rows: u16 = 0;
                    var rank: u64 = 0;
                    const chars = [_]u7{ quad.ch0, quad.ch1, quad.ch2, quad.ch3 };
                    for (chars) |c| {
                        if (c == 0) break;
                        if (c == '\n') {
                            rows +|= 1;
                            head = eval.crux.base;
                            rank = cf.plus(rank, cf.line());
                        } else {
                            rank = cf.plus(rank, cf.text(head, 1));
                            head +|= 1;
                        }
                    }

                    const idea = Idea{
                        .node = eval.node,
                        .last = head,
                        .rows = rows,
                        .rank = rank,
                        .icky = cf.tainted(rank),
                    };

                    if (memo) |m| try m.put(key, idea);
                    exec.* = .{
                        .give = .{
                            .idea = idea,
                            .then = eval.then,
                        },
                    };
                },
                .trip => |trip| {
                    var head = eval.crux.head;
                    var rows: u16 = 0;
                    var rank: u64 = 0;

                    const glyph = trip.slice();
                    const glyph_len = trip.unitLen();
                    const repeats = trip.repeatCount();

                    if (glyph_len != 0 and repeats != 0) {
                        for (0..repeats) |_| {
                            for (glyph[0..glyph_len]) |byte| {
                                if (byte == '\n') {
                                    rows +|= 1;
                                    head = eval.crux.base;
                                    rank = cf.plus(rank, cf.line());
                                } else {
                                    rank = cf.plus(rank, cf.text(head, 1));
                                    head +|= 1;
                                }
                            }
                        }
                    }

                    const idea = Idea{
                        .node = eval.node,
                        .last = head,
                        .rows = rows,
                        .rank = rank,
                        .icky = cf.tainted(rank),
                    };

                    if (memo) |m| try m.put(key, idea);
                    exec.* = .{
                        .give = .{
                            .idea = idea,
                            .then = eval.then,
                        },
                    };
                },
                .cons => |oper| {
                    const pair = tree.heap.cons.items[oper.item];

                    var child_ctx = eval.crux;
                    if (oper.frob.warp == 1)
                        child_ctx.warp();
                    if (oper.frob.nest != 0)
                        child_ctx.nest(oper.frob.nest);

                    exec.* = .{
                        .eval = .{
                            .node = pair.head,
                            .crux = child_ctx,
                            .then = try work.push(tree.bank, Kont{
                                .after_left = .{
                                    .node = eval.node,
                                    .rhs = pair.tail,
                                    .right_base = child_ctx.base,
                                    .head = eval.crux.head,
                                    .base = eval.crux.base,
                                    .next = eval.then,
                                },
                            }),
                        },
                    };
                },
                .fork => |oper| {
                    const pair = tree.heap.fork.items[oper.item];

                    var left_ctx = eval.crux;
                    if (oper.frob.warp == 1)
                        left_ctx.warp();
                    if (oper.frob.nest != 0)
                        left_ctx.nest(oper.frob.nest);

                    const right_ctx = left_ctx;

                    exec.* = .{
                        .fork = .{
                            .left = .{
                                .node = pair.head,
                                .crux = left_ctx,
                                .then = eval.then,
                            },
                            .right = .{
                                .node = pair.tail,
                                .crux = right_ctx,
                                .then = eval.then,
                            },
                        },
                    };
                },
            }
        },
        .give => |give| {
            switch (give.then.*) {
                .done => {
                    exec.* = .{
                        .done = .{ .idea = give.idea },
                    };
                },
                .after_left => |after| {
                    const rhs = after.rhs;
                    const right_base = after.right_base;
                    const orig_head = after.head;
                    const orig_base = after.base;
                    const next = after.next;

                    exec.* = .{
                        .eval = .{
                            .node = rhs,
                            .crux = .{
                                .head = give.idea.last,
                                .base = right_base,
                                .rows = give.idea.rows,
                                .icky = give.idea.icky,
                            },
                            .then = try work.push(tree.bank, Kont{
                                .after_right = .{
                                    .node = after.node,
                                    .head = orig_head,
                                    .base = orig_base,
                                    .left = give.idea,
                                    .next = next,
                                },
                            }),
                        },
                    };
                },
                .after_right => |after| {
                    const left = after.left;
                    const next = after.next;

                    const rank = cf.plus(left.rank, give.idea.rank);

                    const oper = switch (after.node.look()) {
                        .cons => |oper| oper,
                        else => unreachable,
                    };

                    const cons_index: u21 = @intCast(tree.heap.cons.items.len);
                    try tree.heap.cons.append(tree.bank, .{
                        .head = left.node,
                        .tail = give.idea.node,
                    });

                    const layout = Node.fromOper(.cons, oper.frob, cons_index);

                    const idea = Idea{
                        .node = layout,
                        .last = give.idea.last,
                        .rows = left.rows +| give.idea.rows,
                        .rank = rank,
                        .icky = left.icky or give.idea.icky or cf.tainted(rank),
                    };

                    if (memo) |m| {
                        const key = MemoKey{
                            .node = after.node.repr(),
                            .head = after.head,
                            .base = after.base,
                        };
                        try m.put(key, idea);
                    }

                    exec.* = .{
                        .give = .{
                            .idea = idea,
                            .then = next,
                        },
                    };
                },
            }
        },
        .done => {},
        .fork => {},
    }
}

fn costBetter(
    cf: CostFactory,
    lhs: Idea,
    rhs: Idea,
) bool {
    return cf.wins(lhs.rank, rhs.rank);
}

fn dominates(
    cf: CostFactory,
    lhs: Idea,
    rhs: Idea,
) bool {
    if (!lhs.icky and rhs.icky) return true;
    if (lhs.icky and !rhs.icky) return false;
    const lhs_wins = cf.wins(lhs.rank, rhs.rank);
    const rhs_wins = cf.wins(rhs.rank, lhs.rank);
    return lhs_wins and !rhs_wins;
}

fn updateFrontier(
    cf: CostFactory,
    bank: Bank,
    frontier: *std.ArrayList(Idea),
    ickybest: *?Idea,
    idea: Idea,
) !void {
    if (!idea.icky) {
        ickybest.* = null;

        var i: usize = 0;
        while (i < frontier.items.len) {
            const existing = frontier.items[i];
            if (dominates(cf, existing, idea)) {
                return;
            }
            if (dominates(cf, idea, existing)) {
                _ = frontier.swapRemove(i);
                continue;
            }
            i += 1;
        }

        try frontier.append(bank, idea);
        return;
    }

    if (frontier.items.len != 0) return;

    if (ickybest.*) |existing| {
        if (dominates(cf, existing, idea)) return;
        if (dominates(cf, idea, existing) or costBetter(cf, idea, existing)) {
            ickybest.* = idea;
        }
    } else {
        ickybest.* = idea;
    }
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

        pub fn toU64(self: Rank) u64 {
            return @as(u64, self.o) << 16 | self.h;
        }

        pub fn fromU64(val: u64) Rank {
            return .{
                .o = @intCast((val >> 16) & 0xFFFF),
                .h = @intCast(val & 0xFFFF),
            };
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("{d: >5.1}  {d: >3}", .{
                std.math.sqrt(@as(f32, @floatFromInt(self.o))),
                self.h,
            });
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
        return a.key() < b.key();
    }

    fn plusFn(self: *const F1, lhs: u64, rhs: u64) u64 {
        const lhs_rank = Rank.fromU64(lhs);
        const rhs_rank = Rank.fromU64(rhs);
        return self.plus(lhs_rank, rhs_rank).toU64();
    }

    fn lineFn(self: *const F1) u64 {
        return self.line().toU64();
    }

    fn textFn(self: *const F1, c: u16, l: u16) u64 {
        return self.text(c, l).toU64();
    }

    fn winsFn(self: *const F1, a: u64, b: u64) bool {
        const a_rank = Rank.fromU64(a);
        const b_rank = Rank.fromU64(b);
        return self.wins(a_rank, b_rank);
    }

    fn taintedFn(_: *const F1, rank: u64) bool {
        const r = Rank.fromU64(rank);
        return r.o != 0;
    }

    pub fn factory(self: *const F1) CostFactory {
        return .{
            .ptr = self,
            .plusFn = @ptrCast(&plusFn),
            .lineFn = @ptrCast(&lineFn),
            .textFn = @ptrCast(&textFn),
            .winsFn = @ptrCast(&winsFn),
            .taintedFn = @ptrCast(&taintedFn),
        };
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
    w: u64,

    pub const Rank = struct {
        /// the sum of squared overflows
        o: u32 = 0,
        /// the number of newlines
        h: u32 = 0,

        pub fn toU64(self: Rank) u64 {
            return @as(u64, self.o) << 32 | self.h;
        }

        pub fn fromU64(val: u64) Rank {
            return .{
                .o = @intCast((val >> 32) & 0xFFFFFFFF),
                .h = @intCast(val & 0xFFFFFFFF),
            };
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("{d: >5.1}  {d: >3}", .{
                std.math.sqrt(@as(f32, @floatFromInt(self.o))),
                self.h,
            });
        }
    };

    pub fn init(w: u16) F2 {
        return .{ .w = w };
    }

    pub fn line(_: @This()) Rank {
        return .{ .h = 1 };
    }

    pub fn text(this: @This(), c: u16, l: u16) Rank {
        const w: u16 = @intCast(this.w);

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
        return a.toU64() < b.toU64();
    }

    fn plusFn(self: *const F2, lhs: u64, rhs: u64) u64 {
        const lhs_rank = Rank.fromU64(lhs);
        const rhs_rank = Rank.fromU64(rhs);
        return self.plus(lhs_rank, rhs_rank).toU64();
    }

    fn lineFn(self: *const F2) u64 {
        return self.line().toU64();
    }

    fn textFn(self: *const F2, c: u16, l: u16) u64 {
        return self.text(c, l).toU64();
    }

    fn winsFn(self: *const F2, a: u64, b: u64) bool {
        const a_rank = Rank.fromU64(a);
        const b_rank = Rank.fromU64(b);
        return self.wins(a_rank, b_rank);
    }

    fn taintedFn(_: *const F2, rank: u64) bool {
        const r = Rank.fromU64(rank);
        return r.o != 0;
    }

    pub fn factory(self: *const F2) CostFactory {
        return .{
            .ptr = self,
            .plusFn = @ptrCast(&plusFn),
            .lineFn = @ptrCast(&lineFn),
            .textFn = @ptrCast(&textFn),
            .winsFn = @ptrCast(&winsFn),
            .taintedFn = @ptrCast(&taintedFn),
        };
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
};

pub const Quad = packed struct {
    tag: Tag = .quad,
    pad: u1 = 0,
    ch0: u7 = 0,
    ch1: u7 = 0,
    ch2: u7 = 0,
    ch3: u7 = 0,
};

pub const Trip = packed struct {
    tag: Tag = .trip,
    pad: u2 = 0,
    reps: u3 = 0,
    byte0: u8 = 0,
    byte1: u8 = 0,
    byte2: u8 = 0,

    pub fn repeatCount(this: Trip) usize {
        return this.reps;
    }

    pub fn byte(this: Trip, idx: usize) u8 {
        return switch (idx) {
            0 => this.byte0,
            1 => this.byte1,
            2 => this.byte2,
            else => 0,
        };
    }

    pub fn slice(this: Trip) [3]u8 {
        return .{ this.byte0, this.byte1, this.byte2 };
    }

    pub fn unitLen(this: Trip) usize {
        if (this.byte0 == 0) return 0;
        if (this.byte1 == 0) return 1;
        if (this.byte2 == 0) return 2;
        return 3;
    }
};

pub const Rune = packed struct {
    tag: Tag = .rune,
    pad: u2 = 0,
    reps: u6 = 0,
    code: u21 = 0,

    pub fn isEmpty(this: Rune) bool {
        return this.reps == 0;
    }
};

pub const Frob = packed struct {
    /// 1 means align result to current column
    warp: u1 = 0,
    /// apply nest(n, _) to result
    nest: u6 = 0,
    /// unused
    pad: u1 = 0,
};

pub const Oper = packed struct {
    kind: Tag = .cons,
    frob: Frob = .{},
    item: u21 = 0,
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

pub fn List(Elem: type) type {
    return struct {
        pool: std.heap.MemoryPool(Elem),

        pub fn init(bank: Bank) @This() {
            return .{ .pool = std.heap.MemoryPool(Elem).init(bank) };
        }

        pub fn deinit(this: *@This()) void {
            this.pool.deinit();
        }

        pub fn push(this: *@This(), bank: Bank, elem: Elem) !*Elem {
            _ = bank;
            const ptr = try this.pool.create();
            ptr.* = elem;
            return ptr;
        }

        pub fn size(this: *const @This()) usize {
            return this.pool.arena.queryCapacity();
        }
    };
}

pub const Heap = struct {
    text: std.ArrayList(u8) = .empty,
    cons: std.ArrayList(Pair) = .empty,
    fork: std.ArrayList(Pair) = .empty,

    pub fn deinit(this: *@This(), alloc: Bank) void {
        this.text.deinit(alloc);
        this.cons.deinit(alloc);
        this.fork.deinit(alloc);
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
    heap: Heap,
    flatten_cache: std.AutoHashMap(u32, Node),

    pub fn init(bank: Bank) Tree {
        return .{
            .bank = bank,
            .heap = .{},
            .flatten_cache = std.AutoHashMap(u32, Node).init(bank),
        };
    }

    pub fn deinit(tree: *Tree) void {
        tree.heap.deinit(tree.bank);
        tree.flatten_cache.deinit();
    }

    pub fn best(
        tree: *Tree,
        bank: Bank,
        cost: CostFactory,
        node: Node,
        info: ?*std.Io.Writer,
    ) !BestOutcome {
        _ = info;

        const SearchState = struct {
            exec: Exec,
        };

        var konts = List(Kont).init(bank);
        defer konts.deinit();

        var memo = Memo.init(bank);
        defer memo.deinit();

        var work = try std.ArrayList(SearchState).initCapacity(bank, 64);
        defer work.deinit(bank);

        try work.append(bank, .{ .exec = Exec{
            .eval = .{
                .node = node,
                .crux = .{},
                .then = try konts.push(bank, Kont{ .done = {} }),
            },
        } });

        var peak: usize = work.items.len;
        var completions: usize = 0;
        var stats = MachineStats{};

        var good = try std.ArrayList(Idea).initCapacity(bank, 4);
        defer good.deinit(bank);

        var tainted_best: ?Idea = null;

        while (work.pop()) |state| {
            var exec = state.exec;

            while (true) {
                if (good.items.len > 0) {
                    switch (exec) {
                        .eval => |e| {
                            if (e.crux.icky)
                                break;
                        },
                        else => {},
                    }
                }

                switch (exec) {
                    .fork => |branches| {
                        try work.append(bank, .{ .exec = Exec{ .eval = .{
                            .node = branches.right.node,
                            .crux = branches.right.crux,
                            .then = branches.right.then,
                        } } });
                        if (work.items.len > peak) peak = work.items.len;
                        exec = Exec{ .eval = .{
                            .node = branches.left.node,
                            .crux = branches.left.crux,
                            .then = branches.left.then,
                        } };
                        continue;
                    },
                    .done => |done| {
                        try updateFrontier(cost, bank, &good, &tainted_best, done.idea);
                        completions += 1;
                        break;
                    },
                    else => {},
                }

                try machineStep(tree, cost, &konts, &exec, &memo, &stats);
            }
        }

        const memo_entries = memo.count();

        if (good.items.len != 0) {
            var optimal = good.items[0];
            for (good.items[1..]) |candidate| {
                if (costBetter(cost, candidate, optimal)) optimal = candidate;
            }
            return BestOutcome{
                .measure = optimal,
                .completions = completions,
                .memo_hits = stats.memo_hits,
                .memo_misses = stats.memo_misses,
                .memo_entries = memo_entries,
                .frontier_non_tainted = good.items.len,
                .tainted_kept = false,
                .queue_peak = peak,
            };
        }

        if (tainted_best) |tainted| {
            return BestOutcome{
                .measure = tainted,
                .completions = completions,
                .memo_hits = stats.memo_hits,
                .memo_misses = stats.memo_misses,
                .memo_entries = memo_entries,
                .frontier_non_tainted = 0,
                .tainted_kept = true,
                .queue_peak = peak,
            };
        }

        return error.MazeNoLayouts;
    }

    pub fn rank(
        tree: *Tree,
        cf: CostFactory,
        node: Node,
    ) !u64 {
        const outcome = try tree.best(tree.bank, cf, node, null);
        return outcome.measure.rank;
    }

    pub fn emit(tree: *Tree, sink: *std.Io.Writer, node: Node) !void {
        var ctx = Crux{};
        try tree.emitNode(sink, node, &ctx);
    }

    fn emitNode(tree: *Tree, sink: *std.Io.Writer, node: Node, ctx: *Crux) !void {
        switch (node.look()) {
            .rune => |rune| {
                if (rune.reps == 0 or rune.code == 0) return;
                if (rune.code == '\n') {
                    for (0..rune.reps) |_| {
                        try sink.writeByte('\n');
                        if (ctx.base != 0)
                            try sink.splatByteAll(' ', ctx.base);
                    }
                    ctx.head = ctx.base;
                    ctx.rows +|= rune.reps;
                } else {
                    var buffer: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(rune.code, &buffer) catch unreachable;
                    for (0..rune.reps) |_| try sink.writeAll(buffer[0..len]);
                    ctx.head +|= @intCast(len * rune.reps);
                }
            },
            .span => |span| {
                if (span.char != 0 and span.side == .lchr)
                    try emitChar(sink, ctx, span.char);

                const tail = tree.heap.text.items[span.text..];
                const slice = std.mem.sliceTo(tail, 0);
                if (slice.len != 0) {
                    try sink.writeAll(slice);
                    ctx.head +|= @intCast(slice.len);
                }

                if (span.char != 0 and span.side == .rchr)
                    try emitChar(sink, ctx, span.char);
            },
            .quad => |quad| {
                const chars = [_]u7{ quad.ch0, quad.ch1, quad.ch2, quad.ch3 };
                for (chars) |c| {
                    if (c == 0) break;
                    try emitChar(sink, ctx, c);
                }
            },
            .trip => |trip| {
                const glyph = trip.slice();
                const glyph_len = trip.unitLen();
                const repeats = trip.repeatCount();
                if (glyph_len != 0 and repeats != 0) {
                    for (0..repeats) |_| {
                        for (glyph[0..glyph_len]) |byte| {
                            try emitChar(sink, ctx, byte);
                        }
                    }
                }
            },
            .cons => |oper| {
                const pair = tree.heap.cons.items[oper.item];

                var child_ctx = ctx.*;
                if (oper.frob.warp == 1)
                    child_ctx.base = child_ctx.head;
                if (oper.frob.nest != 0)
                    child_ctx.nest(oper.frob.nest);

                try tree.emitNode(sink, pair.head, &child_ctx);

                var right_ctx = child_ctx;
                try tree.emitNode(sink, pair.tail, &right_ctx);

                ctx.head = right_ctx.head;
                ctx.rows = right_ctx.rows;
            },
            .fork => return error.EmitEncounteredFork,
        }
    }

    fn emitChar(sink: *std.Io.Writer, ctx: *Crux, char: u8) !void {
        if (char == '\n') {
            try sink.writeByte('\n');
            if (ctx.base != 0)
                try sink.splatByteAll(' ', ctx.base);
            ctx.head = ctx.base;
            ctx.rows +|= 1;
        } else {
            try sink.writeByte(char);
            ctx.head +|= 1;
        }
    }

    pub fn flat(tree: *Tree, doc: Node) !Node {
        return tree.flattenRec(doc);
    }

    fn flattenRec(tree: *Tree, doc: Node) !Node {
        const key = doc.repr();
        if (tree.flatten_cache.get(key)) |entry| return entry;

        const result = switch (doc.look()) {
            .span => |span| blk: {
                if (span.char != '\n') break :blk doc;
                break :blk Node.fromSpan(span.side, ' ', span.text);
            },
            .quad => doc,
            .trip => doc,
            .rune => |rune| blk: {
                if (rune.code != '\n' or rune.reps == 0) break :blk doc;
                break :blk Node.fromRune(rune.reps, ' ');
            },
            .cons => |oper| blk: {
                const pair = tree.heap.cons.items[oper.item];
                const head = try tree.flattenRec(pair.head);
                const tail = try tree.flattenRec(pair.tail);
                const changed =
                    head.repr() != pair.head.repr() or
                    tail.repr() != pair.tail.repr();
                if (!changed) break :blk doc;

                const next: u21 = @intCast(tree.heap.cons.items.len);
                try tree.heap.cons.append(tree.bank, .{ .head = head, .tail = tail });

                break :blk Node.fromOper(.cons, oper.frob, next);
            },
            .fork => |oper| blk: {
                const pair = tree.heap.fork.items[oper.item];
                const head = try tree.flattenRec(pair.head);
                const tail = try tree.flattenRec(pair.tail);
                const changed =
                    head.repr() != pair.head.repr() or
                    tail.repr() != pair.tail.repr();
                if (!changed) break :blk doc;

                const next: u21 = @intCast(tree.heap.fork.items.len);
                try tree.heap.fork.append(tree.bank, .{ .head = head, .tail = tail });

                break :blk Node.fromOper(.fork, oper.frob, next);
            },
        };

        try tree.flatten_cache.put(key, result);
        return result;
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
        var slab = std.Io.Writer.Allocating.fromArrayList(
            tree.bank,
            &tree.heap.text,
        );
        try slab.writer.print(fmt ++ "\x00", args);

        // Now use text() which will do the deduplication logic for us
        tree.heap.text = slab.toArrayList();
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

    var writer = std.Io.Writer.fixed(buffer);
    try tree.emit(&writer, node);
    try expectEqualStrings(text, writer.buffered());
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
    const result = try tree.best(std.testing.allocator, cost.factory(), doc, null);

    const buf = try std.testing.allocator.alloc(u8, 64);
    defer std.testing.allocator.free(buf);
    var sink = std.Io.Writer.fixed(buf);
    try tree.emit(&sink, result.measure.node);
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

    const cost = F1.init(32);
    const rank = try t.rank(
        cost.factory(),
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

    const s1 = F1.Rank.fromU64(rank);
    try expectEqual(2, s1.h);
    try expectEqual(0, s1.o);
}

test "F2 cost matches example" {
    var t = Tree.init(std.testing.allocator);
    defer t.deinit();

    // See Example 3.5. and Figure 7 in *A Pretty Expressive Printer*.

    const d1 = try t.text("   = func( pretty, print )");
    const cost = F2.init(6);
    const rank1 = try t.rank(cost.factory(), d1);
    const c1 = F2.Rank.fromU64(rank1);

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

    const rank2 = try t.rank(cost.factory(), d2);
    const c2 = F2.Rank.fromU64(rank2);

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
