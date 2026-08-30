const std = @import("std");
const p = @import("pretty.zig");
const build_options = @import("build_options");

fn Evaluator(comptime collect_statistics: bool) type {
    return struct {
        const Candidate = packed struct {
            node: p.Node,
            gist: p.Gist,
        };

        const Frontier = struct {
            const empty_node = std.math.maxInt(u32); // Node tag 7 is invalid.

            nodes: [2]u32 = .{ empty_node, empty_node },
            gists: [2]p.Gist = undefined,

            fn count(frontier: *const Frontier) usize {
                if (frontier.nodes[0] == empty_node) return 0;
                return if (frontier.nodes[1] == empty_node) 1 else 2;
            }

            fn at(frontier: *const Frontier, i: usize) Candidate {
                std.debug.assert(i < frontier.count());
                return .{ .node = @bitCast(frontier.nodes[i]), .gist = frontier.gists[i] };
            }

            fn put(frontier: *Frontier, i: usize, candidate: Candidate) void {
                std.debug.assert(i <= frontier.count() and i < 2);
                frontier.nodes[i] = candidate.node.repr();
                frontier.gists[i] = candidate.gist;
            }

            fn remove(frontier: *Frontier, i: usize) void {
                const len = frontier.count();
                std.debug.assert(i < len);
                if (i + 1 < len) {
                    frontier.nodes[i] = frontier.nodes[len - 1];
                    frontier.gists[i] = frontier.gists[len - 1];
                }
                frontier.nodes[len - 1] = empty_node;
            }

            fn add(frontier: *Frontier, candidate: Candidate) bool {
                var i: usize = 0;
                while (i < frontier.count()) {
                    const existing = frontier.at(i);
                    if (wins(existing.gist, candidate.gist)) return false;
                    if (wins(candidate.gist, existing.gist)) {
                        frontier.remove(i);
                    } else {
                        i += 1;
                    }
                }
                const len = frontier.count();
                if (len == 2)
                    @panic("Pareto frontier exceeds the two-Duel Deck capacity");
                frontier.put(len, candidate);
                return true;
            }

            fn order(frontier: *Frontier) void {
                if (frontier.count() == 2 and frontier.gists[0].last < frontier.gists[1].last) {
                    std.mem.swap(u32, &frontier.nodes[0], &frontier.nodes[1]);
                    std.mem.swap(p.Gist, &frontier.gists[0], &frontier.gists[1]);
                }
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
                var frontier: Frontier = .{};
                frontier.put(0, candidate);
                return .{ .frontier = frontier };
            }

            fn isDelayed(result: *const Result) bool {
                return result.* == .delayed;
            }

            fn isEmpty(result: *const Result) bool {
                return switch (result.*) {
                    .frontier => |frontier| frontier.count() == 0,
                    .delayed => false,
                };
            }

            fn count(result: *const Result) usize {
                return switch (result.*) {
                    .frontier => |frontier| frontier.count(),
                    .delayed => unreachable,
                };
            }

            fn at(result: *const Result, i: usize) Candidate {
                return switch (result.*) {
                    .frontier => |frontier| frontier.at(i),
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
        stat: if (collect_statistics) *p.Stat else void,

        fn deinit(self: *@This()) void {
            self.memo.deinit();
        }

        fn singleton(_: *@This(), node: p.Node, gist: p.Gist) Result {
            return Result.one(.{ .node = node, .gist = gist });
        }

        fn delay(self: *@This(), node: p.Node, crux: p.Crux) Result {
            var forced = crux;
            forced.icky = 1;
            if (comptime collect_statistics) self.stat.cope_deferred += 1;
            return .{ .delayed = .{ .node = node, .crux = forced } };
        }

        fn force(self: *@This(), result: *Result) !void {
            if (!result.isDelayed()) return;
            while (result.isDelayed()) {
                const delayed = result.delayed;
                if (comptime collect_statistics) self.stat.cope_forced += 1;
                try self.eval(delayed.node, delayed.crux, result);
            }
            std.debug.assert(!result.isEmpty());
            const chosen = result.at(0);
            result.* = self.singleton(chosen.node, chosen.gist);
        }

        fn parentCrux(item: p.Item, origin_base: u15) p.Crux {
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

        fn merge(_: *@This(), result: *Result, other: *const Result) void {
            if (result.isEmpty()) {
                result.* = other.*;
                return;
            }
            if (other.isEmpty() or other.isDelayed()) return;
            if (result.isDelayed()) {
                result.* = other.*;
                return;
            }

            var frontier: Frontier = .{};
            for (0..result.count()) |i| _ = frontier.add(result.at(i));
            for (0..other.count()) |i| _ = frontier.add(other.at(i));
            frontier.order();
            result.* = .{ .frontier = frontier };
        }

        fn wrap(self: *@This(), result: *Result, frob: p.Frob) !void {
            if (result.isEmpty() or (frob.warp == 0 and frob.nest == 0)) return;
            for (0..result.count()) |i| {
                const duel = result.at(i);
                const node = try self.tree.cons(frob, duel.node, p.Node.halt);
                result.frontier.put(i, .{ .node = node, .gist = duel.gist });
            }
        }

        fn combine(self: *@This(), head: Candidate, tails: *const Result, frob: p.Frob, result: *Result) !void {
            const first_tail = tails.at(0);
            const first: Candidate = .{
                .node = try self.tree.cons(frob, head.node, first_tail.node),
                .gist = .{ .last = first_tail.gist.last, .rank = self.cost.plus(head.gist.rank, first_tail.gist.rank) },
            };
            if (tails.count() == 1) {
                result.* = self.singleton(first.node, first.gist);
                return;
            }

            const second_tail = tails.at(1);
            const second: Candidate = .{
                .node = try self.tree.cons(frob, head.node, second_tail.node),
                .gist = .{ .last = second_tail.gist.last, .rank = self.cost.plus(head.gist.rank, second_tail.gist.rank) },
            };
            if (costLe(second.gist.rank, first.gist.rank)) {
                result.* = self.singleton(second.node, second.gist);
                return;
            }
            var frontier: Frontier = .{};
            frontier.put(0, first);
            frontier.put(1, second);
            result.* = .{ .frontier = frontier };
        }

        fn evalMemoHcat(self: *@This(), node: p.Node, tail: p.Node, frob: p.Frob, crux0: p.Crux, result: *Result) !void {
            const origin = crux0;
            var crux = crux0;
            if (frob.warp == 1) crux.warp();
            if (frob.nest != 0) crux.nest(frob.nest);
            const item = crux.item(node);
            const store = self.memoize and crux.icky == 0 and crux.last <= self.limit and crux.base <= self.limit;
            if (store) {
                if (self.memo.getPtr(item)) |deck| {
                    if (comptime collect_statistics) {
                        self.stat.memo_hits += 1;
                        self.stat.memo_hits_hcat += 1;
                    }
                    result.* = deck.*;
                    return;
                }
                if (comptime collect_statistics) {
                    self.stat.memo_misses += 1;
                    self.stat.memo_misses_hcat += 1;
                }
            }
            try self.eval(tail, crux, result);
            if (result.isDelayed() and origin.icky != 0) try self.force(result);
            if (result.isDelayed()) {
                result.* = self.delay(node, parentCrux(item, origin.base));
            } else {
                try self.wrap(result, frob);
            }
            if (store) try self.memo.put(item, result.*);
        }

        fn evalHcat(self: *@This(), node: p.Node, oper: p.Oper, crux0: p.Crux, result: *Result) !void {
            const pair = self.tree.heap.new().hcat.list.items[oper.item];
            // Keep memo-specific Result temporaries out of the ordinary recursive frame.
            if (pair.head == p.Node.memo_mark)
                return @call(.never_inline, evalMemoHcat, .{ self, node, pair.tail, oper.frob, crux0, result });

            const origin = crux0;
            var crux = crux0;
            if (oper.frob.warp == 1) crux.warp();
            if (oper.frob.nest != 0) crux.nest(oper.frob.nest);
            const item = crux.item(node);

            var heads: Result = undefined;
            try self.eval(pair.head, crux, &heads);
            if (heads.isDelayed() and origin.icky != 0) try self.force(&heads);
            if (heads.isDelayed()) {
                result.* = self.delay(node, parentCrux(item, origin.base));
                return;
            }
            if (heads.isEmpty()) {
                result.* = Result.none();
                return;
            }

            result.* = Result.none();
            for (0..heads.count()) |i| {
                const head = heads.at(i);
                var tails: Result = undefined;
                try self.eval(pair.tail, .{
                    .base = crux.base,
                    .last = head.gist.last,
                    .icky = @intFromBool(origin.icky != 0 and head.gist.rows() == 0),
                }, &tails);
                if (tails.isDelayed() and origin.icky != 0) try self.force(&tails);
                if (tails.isDelayed()) {
                    const delayed = self.delay(node, parentCrux(item, origin.base));
                    self.merge(result, &delayed);
                } else if (!tails.isEmpty()) {
                    var combined: Result = undefined;
                    try self.combine(head, &tails, oper.frob, &combined);
                    self.merge(result, &combined);
                }
            }
        }

        fn evalFork(self: *@This(), node: p.Node, oper: p.Oper, crux0: p.Crux, result: *Result) !void {
            const pair = self.tree.heap.new().fork.list.items[oper.item];
            const origin = crux0;
            var crux = crux0;
            if (oper.frob.warp == 1) crux.warp();
            if (oper.frob.nest != 0) crux.nest(oper.frob.nest);
            const item = crux.item(node);

            try self.eval(pair.head, crux, result);
            if (result.isDelayed() and origin.icky != 0) try self.force(result);
            if (origin.icky != 0) return self.wrap(result, oper.frob);

            var right: Result = undefined;
            try self.eval(pair.tail, .{ .base = crux.base, .last = item.head }, &right);
            self.merge(result, &right);
            if (result.isDelayed()) {
                result.* = self.delay(node, parentCrux(item, origin.base));
                return;
            }
            try self.wrap(result, oper.frob);
        }

        fn eval(self: *@This(), node: p.Node, crux: p.Crux, result: *Result) anyerror!void {
            if (crux.icky == 0 and self.terminalExceedsLimit(node, crux)) {
                result.* = self.delay(node, crux);
                return;
            }
            switch (node.look()) {
                .rune => |rune| result.* = self.singleton(node, rune.toGist(crux, self.cost)),
                .span => |span| result.* = self.singleton(node, span.toGist(crux, self.cost, self.tree)),
                .quad => |quad| result.* = self.singleton(node, quad.toGist(crux, self.cost)),
                .trip => |trip| result.* = self.singleton(node, trip.toGist(crux, self.cost)),
                .hcat => |oper| if (build_options.profile_outline)
                    try @call(.never_inline, evalHcat, .{ self, node, oper, crux, result })
                else
                    try self.evalHcat(node, oper, crux, result),
                .fork => |oper| if (build_options.profile_outline)
                    try @call(.never_inline, evalFork, .{ self, node, oper, crux, result })
                else
                    try self.evalFork(node, oper, crux, result),
                .cons => unreachable,
            }
        }

        fn run(self: *@This(), root: p.Node) !p.Best {
            var deck: Result = undefined;
            try self.eval(root, .{}, &deck);
            if (deck.isDelayed()) try self.force(&deck);
            var completed: Frontier = .{};
            for (0..deck.count()) |i| {
                if (completed.add(deck.at(i))) {
                    if (comptime collect_statistics) self.stat.completions += 1;
                }
            }
            if (comptime collect_statistics) {
                self.stat.size = completed.count();
                self.stat.memo_entries = self.memo.count();
                self.stat.heap_peak = self.tree.heap.size();
            }
            if (completed.count() == 0) return error.NoLayout;
            var boss = completed.at(0);
            if (completed.count() == 2 and self.cost.wins(completed.at(1).gist.rank, boss.gist.rank)) {
                boss = completed.at(1);
            }
            return .{ .idea = .{ .node = boss.node, .gist = boss.gist } };
        }
    };
}

test "recursive evaluator records stay compact" {
    const BareEvaluator = Evaluator(false);
    try std.testing.expectEqual(16, @sizeOf(BareEvaluator.Candidate));
    try std.testing.expectEqual(24, @sizeOf(BareEvaluator.Frontier));
    try std.testing.expectEqual(8, @sizeOf(BareEvaluator.Delay));
    try std.testing.expectEqual(32, @sizeOf(BareEvaluator.Result));
    try std.testing.expect(@sizeOf(BareEvaluator) < @sizeOf(Evaluator(true)));
}

pub fn pickWithOptions(
    tree: *p.Tree,
    bank: std.mem.Allocator,
    cost: p.Cost,
    node: p.Node,
    options: p.PickOptions,
) !p.Best {
    var evaluator: Evaluator(false) = .{
        .tree = tree,
        .cost = cost,
        .limit = options.computation_width orelse cost.defaultComputationWidth(),
        .memoize = options.memoize,
        .memo = .init(bank),
        .stat = {},
    };
    defer evaluator.deinit();
    return evaluator.run(node);
}

pub fn pickWithStatistics(
    tree: *p.Tree,
    bank: std.mem.Allocator,
    cost: p.Cost,
    node: p.Node,
    options: p.PickOptions,
    stat: *p.Stat,
) !p.Best {
    stat.* = .{};
    var evaluator: Evaluator(true) = .{
        .tree = tree,
        .cost = cost,
        .limit = options.computation_width orelse cost.defaultComputationWidth(),
        .memoize = options.memoize,
        .memo = .init(bank),
        .stat = stat,
    };
    defer evaluator.deinit();
    return evaluator.run(node);
}
