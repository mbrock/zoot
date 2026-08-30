const std = @import("std");
const p = @import("pretty.zig");

const Evaluator = struct {
    tree: *p.Tree,
    bank: std.mem.Allocator,
    cost: p.Cost,
    limit: u16,
    memoize: bool,
    memo: p.Memo,
    stat: p.Stat = .{},
    best: std.ArrayList(p.Idea) = .empty,

    fn deinit(self: *@This()) void {
        self.memo.deinit();
        self.best.deinit(self.bank);
    }

    fn singleton(self: *@This(), node: p.Node, gist: p.Gist) !p.Deck {
        const idx = try self.tree.heap.new().duel.push(self.bank, .{ .node = node, .gist = gist });
        return p.Deck.one(self.tree.heap.tick, @intCast(idx));
    }

    fn delay(self: *@This(), node: p.Node, crux: p.Crux) !p.Deck {
        var forced = crux;
        forced.icky = true;
        const idx = try self.tree.heap.new().cope.push(self.bank, .{ .node = node, .crux = forced });
        self.stat.cope_deferred += 1;
        return p.Deck.thunk(self.tree.heap.tick, @intCast(idx));
    }

    fn force(self: *@This(), deck: p.Deck) !p.Deck {
        if (!deck.isCope()) return deck;
        const cope = self.tree.heap.new().cope.list.items[deck.copeItem()];
        self.stat.cope_forced += 1;
        const forced = try self.eval(cope.node, cope.crux);
        if (forced.isCope()) return self.force(forced);
        std.debug.assert(!forced.isEmpty());
        const chosen = forced.candidate(0, &self.tree.heap);
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

    fn prepend(self: *@This(), deck: p.Deck, node: p.Node, gist: p.Gist) !p.Deck {
        if (deck.isCope() or deck.duelCount() >= 2)
            @panic("Pareto frontier exceeds the two-Duel Deck capacity");
        if (deck.isEmpty()) return self.singleton(node, gist);
        const idx = try self.tree.heap.new().duel.push(self.bank, .{ .node = node, .gist = gist });
        return p.Deck.two(self.tree.heap.tick, @intCast(idx), deck.duelItem(0));
    }

    fn merge(self: *@This(), a: p.Deck, b: p.Deck) !p.Deck {
        if (a.isEmpty()) return b;
        if (b.isEmpty() or b.isCope()) return a;
        if (a.isCope()) return b;

        var result = p.Deck.none;
        var ai: usize = 0;
        var bi: usize = 0;
        while (ai < a.duelCount() or bi < b.duelCount()) {
            if (ai == a.duelCount()) {
                const duel = b.candidate(bi, &self.tree.heap);
                result = try self.prepend(result, duel.node, duel.gist);
                bi += 1;
            } else if (bi == b.duelCount()) {
                const duel = a.candidate(ai, &self.tree.heap);
                result = try self.prepend(result, duel.node, duel.gist);
                ai += 1;
            } else {
                const ad = a.candidate(ai, &self.tree.heap);
                const bd = b.candidate(bi, &self.tree.heap);
                if (wins(ad.gist, bd.gist)) {
                    bi += 1;
                } else if (wins(bd.gist, ad.gist)) {
                    ai += 1;
                } else if (ad.gist.last > bd.gist.last) {
                    result = try self.prepend(result, ad.node, ad.gist);
                    ai += 1;
                } else {
                    result = try self.prepend(result, bd.node, bd.gist);
                    bi += 1;
                }
            }
        }
        return result.reversed();
    }

    fn wrap(self: *@This(), deck: p.Deck, frob: p.Frob) !p.Deck {
        if (deck.isEmpty() or (frob.warp == 0 and frob.nest == 0)) return deck;
        var reversed = p.Deck.none;
        for (0..deck.duelCount()) |i| {
            const duel = deck.candidate(i, &self.tree.heap);
            const node = try self.tree.cons(frob, duel.node, p.Node.halt);
            reversed = try self.prepend(reversed, node, duel.gist);
        }
        return reversed.reversed();
    }

    fn combine(self: *@This(), head: p.Duel, tails: p.Deck, frob: p.Frob) !p.Deck {
        var reversed = p.Deck.none;
        var current: ?p.Idea = null;
        for (0..tails.duelCount()) |i| {
            const tail = tails.candidate(i, &self.tree.heap);
            const idea: p.Idea = .{
                .node = try self.tree.cons(frob, head.node, tail.node),
                .gist = .{ .last = tail.gist.last, .rank = self.cost.plus(head.gist.rank, tail.gist.rank) },
            };
            if (current) |best| {
                if (costLe(idea.gist.rank, best.gist.rank)) {
                    current = idea;
                } else {
                    reversed = try self.prepend(reversed, best.node, best.gist);
                    current = idea;
                }
            } else current = idea;
        }
        if (current) |best| reversed = try self.prepend(reversed, best.node, best.gist);
        return reversed.reversed();
    }

    fn evalHcat(self: *@This(), node: p.Node, oper: p.Oper, crux0: p.Crux) !p.Deck {
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
            if (child.isCope() and origin.icky) child = try self.force(child);
            const result = if (child.isCope())
                try self.delay(node, parentCrux(item, origin.base))
            else
                try self.wrap(child, oper.frob);
            if (store) try self.memo.put(item, result);
            return result;
        }

        var heads = try self.eval(pair.head, crux);
        if (heads.isCope() and origin.icky) heads = try self.force(heads);
        if (heads.isCope()) return self.delay(node, parentCrux(item, origin.base));
        if (heads.isEmpty()) return p.Deck.none;

        var result = p.Deck.none;
        for (0..heads.duelCount()) |i| {
            const head = heads.candidate(i, &self.tree.heap);
            var tails = try self.eval(pair.tail, .{
                .base = crux.base,
                .last = head.gist.last,
                .rows = head.gist.rows(),
                .icky = origin.icky and head.gist.rows() == 0,
            });
            if (tails.isCope() and origin.icky) tails = try self.force(tails);
            if (tails.isCope()) {
                result = try self.merge(result, try self.delay(node, parentCrux(item, origin.base)));
            } else if (!tails.isEmpty()) {
                result = try self.merge(result, try self.combine(head, tails, oper.frob));
            }
        }
        return result;
    }

    fn evalFork(self: *@This(), node: p.Node, oper: p.Oper, crux0: p.Crux) !p.Deck {
        const pair = self.tree.heap.new().fork.list.items[oper.item];
        const origin = crux0;
        var crux = crux0;
        if (oper.frob.warp == 1) crux.warp();
        if (oper.frob.nest != 0) crux.nest(oper.frob.nest);
        const item = crux.item(node);

        var left = try self.eval(pair.head, crux);
        if (left.isCope() and origin.icky) left = try self.force(left);
        if (origin.icky) return self.wrap(left, oper.frob);

        const right = try self.eval(pair.tail, .{ .base = crux.base, .last = item.head });
        const merged = try self.merge(left, right);
        if (merged.isCope()) return self.delay(node, parentCrux(item, origin.base));
        return self.wrap(merged, oper.frob);
    }

    fn eval(self: *@This(), node: p.Node, crux: p.Crux) anyerror!p.Deck {
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

    fn meld(self: *@This(), idea: p.Idea) !void {
        var i: usize = 0;
        while (i < self.best.items.len) {
            const item = self.best.items[i];
            if (wins(item.gist, idea.gist)) return;
            if (wins(idea.gist, item.gist)) _ = self.best.swapRemove(i) else i += 1;
        }
        try self.best.append(self.bank, idea);
        self.stat.completions += 1;
    }

    fn run(self: *@This(), root: p.Node) !p.Best {
        var deck = try self.eval(root, .{});
        while (deck.isCope()) deck = try self.force(deck);
        for (0..deck.duelCount()) |i| {
            const duel = deck.candidate(i, &self.tree.heap);
            try self.meld(.{ .node = duel.node, .gist = duel.gist });
        }
        self.stat.size = self.best.items.len;
        self.stat.memo_entries = self.memo.count();
        self.stat.heap_peak = self.tree.heap.size();
        if (self.best.items.len == 0) return error.NoLayout;
        var boss = self.best.items[0];
        for (self.best.items[1..]) |idea| {
            if (self.cost.wins(idea.gist.rank, boss.gist.rank)) boss = idea;
        }
        return .{ .idea = boss, .stat = self.stat };
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
        .bank = bank,
        .cost = cost,
        .limit = options.computation_width orelse cost.defaultComputationWidth(),
        .memoize = options.memoize,
        .memo = p.Memo.init(bank),
    };
    defer evaluator.deinit();
    return evaluator.run(node);
}
