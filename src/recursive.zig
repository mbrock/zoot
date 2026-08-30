const std = @import("std");
const p = @import("pretty.zig");

const Evaluator = struct {
    const Candidate = packed struct {
        node: p.Node,
        gist: p.Gist,
    };

    const Frontier = struct {
        items: [2]Candidate = undefined,
        len: u2 = 0,

        fn add(frontier: *Frontier, candidate: Candidate) bool {
            var i: usize = 0;
            while (i < frontier.len) {
                if (wins(frontier.items[i].gist, candidate.gist)) return false;
                if (wins(candidate.gist, frontier.items[i].gist)) {
                    frontier.len -= 1;
                    if (i < frontier.len) frontier.items[i] = frontier.items[frontier.len];
                } else {
                    i += 1;
                }
            }
            if (frontier.len == 2)
                @panic("Pareto frontier exceeds the two-Duel Deck capacity");
            frontier.items[frontier.len] = candidate;
            frontier.len += 1;
            return true;
        }

        fn order(frontier: *Frontier) void {
            if (frontier.len == 2 and frontier.items[0].gist.last < frontier.items[1].gist.last)
                std.mem.swap(Candidate, &frontier.items[0], &frontier.items[1]);
        }
    };

    const Delay = struct {
        node: p.Node,
        crux: p.Crux,
    };

    const Result = union(enum) {
        frontier: Frontier,
        delayed: Delay,

        fn none() Result {
            return .{ .frontier = .{} };
        }

        fn one(candidate: Candidate) Result {
            return .{ .frontier = .{ .items = .{ candidate, undefined }, .len = 1 } };
        }

        fn isDelayed(result: Result) bool {
            return result == .delayed;
        }

        fn isEmpty(result: Result) bool {
            return switch (result) {
                .frontier => |frontier| frontier.len == 0,
                .delayed => false,
            };
        }

        fn count(result: Result) usize {
            return switch (result) {
                .frontier => |frontier| frontier.len,
                .delayed => unreachable,
            };
        }

        fn at(result: Result, i: usize) Candidate {
            return switch (result) {
                .frontier => |frontier| frontier.items[i],
                .delayed => unreachable,
            };
        }
    };

    const ItemHashContext = struct {
        pub fn hash(_: @This(), item: p.Item) u64 {
            const word: u64 = @bitCast(item);
            const mixed = word *% 0x9e3779b97f4a7c15;
            return mixed ^ (mixed >> 29);
        }

        pub fn eql(_: @This(), a: p.Item, b: p.Item) bool {
            return a == b;
        }
    };

    const Memo = std.HashMap(p.Item, Result, ItemHashContext, 80);

    tree: *p.Tree,
    cost: p.Cost,
    limit: u16,
    memoize: bool,
    memo: Memo,
    stat: p.Stat = .{},

    fn deinit(self: *@This()) void {
        self.memo.deinit();
    }

    fn singleton(_: *@This(), node: p.Node, gist: p.Gist) Result {
        return Result.one(.{ .node = node, .gist = gist });
    }

    fn delay(self: *@This(), node: p.Node, crux: p.Crux) Result {
        var forced = crux;
        forced.icky = true;
        self.stat.cope_deferred += 1;
        return .{ .delayed = .{ .node = node, .crux = forced } };
    }

    fn force(self: *@This(), result: Result) !Result {
        if (!result.isDelayed()) return result;
        const delayed = result.delayed;
        self.stat.cope_forced += 1;
        const forced = try self.eval(delayed.node, delayed.crux);
        if (forced.isDelayed()) return self.force(forced);
        std.debug.assert(!forced.isEmpty());
        const chosen = forced.at(0);
        return self.singleton(chosen.node, chosen.gist);
    }

    fn parentCrux(item: p.Item, origin_base: u16) p.Crux {
        return .{ .last = item.head, .base = origin_base };
    }

    fn terminalExceedsLimit(self: *@This(), node: p.Node, crux: p.Crux) bool {
        var column: u32 = crux.last;
        if (column > self.limit or crux.base > self.limit) return true;
        return switch (node.look()) {
            .rune => |rune| blk: {
                if (rune.code == '\n') break :blk false;
                const width = std.unicode.utf8CodepointSequenceLength(rune.code) catch 1;
                column += @as(u32, width) * rune.reps;
                break :blk column > self.limit;
            },
            .span => |span| blk: {
                if (span.char != 0 and span.side == .lchr) {
                    if (span.char == '\n') column = crux.base else column += 1;
                    if (column > self.limit) break :blk true;
                }
                const text = std.mem.sliceTo(self.tree.blob.items[span.text..], 0);
                column += @intCast(text.len);
                if (column > self.limit) break :blk true;
                if (span.char != 0 and span.side == .rchr) {
                    if (span.char == '\n') column = crux.base else column += 1;
                }
                break :blk column > self.limit;
            },
            .quad => |quad| blk: {
                for ([_]u7{ quad.ch0, quad.ch1, quad.ch2, quad.ch3 }) |char| {
                    if (char == 0) break;
                    if (char == '\n') column = crux.base else column += 1;
                    if (column > self.limit) break :blk true;
                }
                break :blk false;
            },
            .trip => |trip| blk: {
                const glyph = trip.slice();
                for (0..trip.repeatCount()) |_| {
                    for (glyph[0..trip.unitLen()]) |char| {
                        if (char == '\n') column = crux.base else column += 1;
                        if (column > self.limit) break :blk true;
                    }
                }
                break :blk false;
            },
            else => false,
        };
    }

    fn costLe(a: p.Rank, b: p.Rank) bool {
        return a.toU64() <= b.toU64();
    }

    fn wins(a: p.Gist, b: p.Gist) bool {
        return a.last <= b.last and costLe(a.rank, b.rank);
    }

    fn merge(_: *@This(), a: Result, b: Result) Result {
        if (a.isEmpty()) return b;
        if (b.isEmpty()) return a;
        if (b.isDelayed()) return a;
        if (a.isDelayed()) return b;

        var result: Frontier = .{};
        for (0..a.count()) |i| _ = result.add(a.at(i));
        for (0..b.count()) |i| _ = result.add(b.at(i));
        result.order();
        return .{ .frontier = result };
    }

    fn wrap(self: *@This(), result0: Result, frob: p.Frob) !Result {
        if (result0.isEmpty() or (frob.warp == 0 and frob.nest == 0)) return result0;
        var result: Frontier = .{};
        for (0..result0.count()) |i| {
            const duel = result0.at(i);
            const node = try self.tree.cons(frob, duel.node, p.Node.halt);
            result.items[result.len] = .{ .node = node, .gist = duel.gist };
            result.len += 1;
        }
        return .{ .frontier = result };
    }

    fn combine(self: *@This(), head: Candidate, tails: Result, frob: p.Frob) !Result {
        const first_tail = tails.at(0);
        const first: Candidate = .{
            .node = try self.tree.cons(frob, head.node, first_tail.node),
            .gist = .{ .last = first_tail.gist.last, .rank = self.cost.plus(head.gist.rank, first_tail.gist.rank) },
        };
        if (tails.count() == 1) return self.singleton(first.node, first.gist);

        const second_tail = tails.at(1);
        const second: Candidate = .{
            .node = try self.tree.cons(frob, head.node, second_tail.node),
            .gist = .{ .last = second_tail.gist.last, .rank = self.cost.plus(head.gist.rank, second_tail.gist.rank) },
        };
        if (costLe(second.gist.rank, first.gist.rank)) {
            return self.singleton(second.node, second.gist);
        }
        return .{ .frontier = .{
            .items = .{ first, second },
            .len = 2,
        } };
    }

    fn evalHcat(self: *@This(), node: p.Node, oper: p.Oper, crux0: p.Crux) !Result {
        const pair = self.tree.heap.new().hcat.list.items[oper.item];
        const origin = crux0;
        var crux = crux0;
        if (oper.frob.warp == 1) crux.warp();
        if (oper.frob.nest != 0) crux.nest(oper.frob.nest);
        const item = crux.item(node);

        if (pair.head == p.Node.memo_mark) {
            const store = self.memoize and !crux.icky and crux.last <= self.limit and crux.base <= self.limit;
            if (store) {
                if (self.memo.get(item)) |deck| {
                    self.stat.memo_hits += 1;
                    self.stat.memo_hits_hcat += 1;
                    return deck;
                }
                self.stat.memo_misses += 1;
                self.stat.memo_misses_hcat += 1;
            }
            var child = try self.eval(pair.tail, crux);
            if (child.isDelayed() and origin.icky) child = try self.force(child);
            const result = if (child.isDelayed())
                self.delay(node, parentCrux(item, origin.base))
            else
                try self.wrap(child, oper.frob);
            if (store) try self.memo.put(item, result);
            return result;
        }

        var heads = try self.eval(pair.head, crux);
        if (heads.isDelayed() and origin.icky) heads = try self.force(heads);
        if (heads.isDelayed()) return self.delay(node, parentCrux(item, origin.base));
        if (heads.isEmpty()) return Result.none();

        var result = Result.none();
        for (0..heads.count()) |i| {
            const head = heads.at(i);
            var tails = try self.eval(pair.tail, .{
                .base = crux.base,
                .last = head.gist.last,
                .rows = head.gist.rows(),
                .icky = origin.icky and head.gist.rows() == 0,
            });
            if (tails.isDelayed() and origin.icky) tails = try self.force(tails);
            if (tails.isDelayed()) {
                result = self.merge(result, self.delay(node, parentCrux(item, origin.base)));
            } else if (!tails.isEmpty()) {
                result = self.merge(result, try self.combine(head, tails, oper.frob));
            }
        }
        return result;
    }

    fn evalFork(self: *@This(), node: p.Node, oper: p.Oper, crux0: p.Crux) !Result {
        const pair = self.tree.heap.new().fork.list.items[oper.item];
        const origin = crux0;
        var crux = crux0;
        if (oper.frob.warp == 1) crux.warp();
        if (oper.frob.nest != 0) crux.nest(oper.frob.nest);
        const item = crux.item(node);

        var left = try self.eval(pair.head, crux);
        if (left.isDelayed() and origin.icky) left = try self.force(left);
        if (origin.icky) return self.wrap(left, oper.frob);

        const right = try self.eval(pair.tail, .{ .base = crux.base, .last = item.head });
        const merged = self.merge(left, right);
        if (merged.isDelayed()) return self.delay(node, parentCrux(item, origin.base));
        return self.wrap(merged, oper.frob);
    }

    fn eval(self: *@This(), node: p.Node, crux: p.Crux) anyerror!Result {
        if (!crux.icky and self.terminalExceedsLimit(node, crux))
            return self.delay(node, crux);
        return switch (node.look()) {
            .rune => |rune| self.singleton(node, rune.toGist(crux, self.cost)),
            .span => |span| self.singleton(node, span.toGist(crux, self.cost, self.tree)),
            .quad => |quad| self.singleton(node, quad.toGist(crux, self.cost)),
            .trip => |trip| self.singleton(node, trip.toGist(crux, self.cost)),
            .hcat => |oper| self.evalHcat(node, oper, crux),
            .fork => |oper| self.evalFork(node, oper, crux),
            .cons => unreachable,
        };
    }

    fn run(self: *@This(), root: p.Node) !p.Best {
        var deck = try self.eval(root, .{});
        while (deck.isDelayed()) deck = try self.force(deck);
        var completed: Frontier = .{};
        for (0..deck.count()) |i| {
            if (completed.add(deck.at(i))) self.stat.completions += 1;
        }
        self.stat.size = completed.len;
        self.stat.memo_entries = self.memo.count();
        self.stat.heap_peak = self.tree.heap.size();
        if (completed.len == 0) return error.NoLayout;
        var boss = completed.items[0];
        if (completed.len == 2 and self.cost.wins(completed.items[1].gist.rank, boss.gist.rank)) {
            boss = completed.items[1];
        }
        return .{ .idea = .{ .node = boss.node, .gist = boss.gist }, .stat = self.stat };
    }
};

pub fn pickWithOptions(
    tree: *p.Tree,
    bank: std.mem.Allocator,
    cost: p.Cost,
    node: p.Node,
    options: p.PickOptions,
) !p.Best {
    var evaluator: Evaluator = .{
        .tree = tree,
        .cost = cost,
        .limit = options.computation_width orelse cost.defaultComputationWidth(),
        .memoize = options.memoize,
        .memo = .init(bank),
    };
    defer evaluator.deinit();
    return evaluator.run(node);
}
