const std = @import("std");
const build_options = @import("build_options");
const log = std.log;

pub const Bank = std.mem.Allocator;

/// This implements the algorithm from
fn EvalLoop(comptime collect_statistics: bool) type {
    return struct {
        tree: *Tree,
        heap: *Heap,
        cost: Cost,
        memo: Memo,
        root: Node,
        exec: Exec,
        stat: if (collect_statistics) *Stat else void,
        best: std.ArrayList(Idea) = .empty,
        icky: ?Idea = null,
        tide: usize = 100_000_000,
        limit: u16,
        trace_gc: if (collect_statistics) bool else void,
        trace_memo: if (collect_statistics) bool else void,
        memoize: bool = true,
        memo_hit_regions: if (collect_statistics) [3]usize else void,
        memo_miss_regions: if (collect_statistics) [3]usize else void,
        gc_poll: u8 = 0,

        pub fn deinit(this: *@This()) void {
            this.best.deinit(this.heap.bank);
            this.memo.deinit();
        }

        fn tidy(this: *@This()) !void {
            const before = this.heap.size();
            if (comptime collect_statistics) {
                if (this.trace_gc) {
                    std.debug.print(
                        "gc {d} before: heap={Bi:.2} memo={d}\n",
                        .{ this.stat.gc_count + 1, before, this.memo.count() },
                    );
                    this.heap.new().dump();
                }
            }

            this.heap.flip();
            var memo = Memo.init(this.tree.bank);
            try this.heap.hash(&this.memo, &memo);
            this.memo.deinit();
            this.memo = memo;

            try this.heap.move(&this.exec);
            try this.heap.move(&this.root);

            for (this.best.items) |*idea|
                try this.heap.move(idea);
            if (this.icky) |*icky|
                try this.heap.move(icky);

            try this.heap.scan();
            const after = this.heap.size();
            if (comptime collect_statistics) {
                this.stat.gc_count += 1;
                this.stat.gc_before_peak = @max(this.stat.gc_before_peak, before);
                this.stat.gc_live_peak = @max(this.stat.gc_live_peak, after);
                this.stat.gc_live_last = after;
                this.stat.gc_copied_total +|= after;

                if (this.trace_gc) {
                    std.debug.print(
                        "gc {d} after: heap={Bi:.2} memo={d}\n",
                        .{ this.stat.gc_count, after, this.memo.count() },
                    );
                    this.heap.new().dump();
                }
            }
        }

        fn fuss(this: *@This()) !void {
            const size = this.heap.size();
            if (comptime collect_statistics)
                this.stat.heap_peak = @max(this.stat.heap_peak, size);
            if (size < this.tide) return;
            //        const size0 = this.heap.size();
            try this.tidy();
            const size1 = this.heap.size();
            //        log.info("gc: heap {Bi:>6.2} to {Bi:>6.2}", .{ size0, size1 });
            this.tide = @max(this.tide, size1 + size1 * 2);
        }

        fn pick(
            tree: *Tree,
            bank: Bank,
            cost: Cost,
            node: Node,
            options: PickOptions,
            stat: if (collect_statistics) *Stat else void,
        ) !Best {
            var this = @This(){
                .tree = tree,
                .heap = &tree.heap,
                .cost = cost,
                .memo = .init(bank),
                .root = node,
                .exec = .{
                    .node = node,
                    .tick = .{ .eval = .{} },
                },
                .stat = stat,
                .tide = options.gc_tide,
                .limit = options.computation_width orelse cost.defaultComputationWidth(),
                .trace_gc = if (collect_statistics) options.trace_gc else {},
                .trace_memo = if (collect_statistics) options.trace_memo else {},
                .memoize = options.memoize,
                .memo_hit_regions = if (collect_statistics) .{ 0, 0, 0 } else {},
                .memo_miss_regions = if (collect_statistics) .{ 0, 0, 0 } else {},
            };
            defer this.deinit();

            return this.loop();
        }

        pub fn loop(this: *@This()) !Best {
            if (build_options.profile_outline)
                try @call(.never_inline, explore, .{this})
            else
                try this.explore();
            try this.fuss();

            if (comptime collect_statistics) {
                this.stat.size = this.best.items.len;
                this.stat.memo_entries = this.memo.count();
                if (this.trace_memo) try this.dumpMemo();
            }

            if (this.best.items.len != 0) {
                var boss = this.best.items[0];
                for (this.best.items[1..]) |chap| {
                    if (this.cost.wins(chap.gist.rank, boss.gist.rank))
                        boss = chap;
                }

                log.debug("SELECTED BEST: node={s} overflow={d} height={d} last={d}", .{
                    @tagName(boss.node.tag),
                    boss.gist.rank.o,
                    boss.gist.rank.h,
                    boss.gist.last,
                });

                return Best{ .idea = boss };
            }

            if (this.icky) |icky|
                return Best{ .idea = icky };

            std.debug.panic("zero layouts discovered", .{});
        }

        fn distributionBucket(value: usize) usize {
            if (value <= 1) return value;
            if (value <= 2) return 2;
            if (value <= 4) return 3;
            if (value <= 8) return 4;
            if (value <= 16) return 5;
            return 6;
        }

        fn contextRegion(this: *@This(), item: Item) usize {
            const width = this.cost.width();
            const reference_limit = width + width / 5;
            const edge = @max(item.head, item.base);
            if (edge <= width) return 0;
            if (edge <= reference_limit) return 1;
            return 2;
        }

        fn dumpMemo(this: *@This()) !void {
            var node_contexts = std.AutoHashMap(Node, usize).init(this.tree.bank);
            defer node_contexts.deinit();
            var contexts = std.AutoHashMap(u32, void).init(this.tree.bank);
            defer contexts.deinit();
            var frontier_roots = std.AutoHashMap(Deck, void).init(this.tree.bank);
            defer frontier_roots.deinit();

            var tags = [_]usize{0} ** 8;
            var frontier_buckets = [_]usize{0} ** 7;
            var context_buckets = [_]usize{0} ** 7;
            var frontier_cells: usize = 0;
            var frontier_max: usize = 0;
            var empty: usize = 0;
            var thunks: usize = 0;
            var head_max: u16 = 0;
            var base_max: u16 = 0;
            var entry_regions = [_]usize{0} ** 3;

            var iter = this.memo.iterator();
            while (iter.next()) |entry| {
                const item = entry.key_ptr.*;
                const deck = entry.value_ptr.*;
                tags[@intFromEnum(item.node.tag)] += 1;
                head_max = @max(head_max, item.head);
                base_max = @max(base_max, item.base);
                entry_regions[this.contextRegion(item)] += 1;
                try contexts.put((@as(u32, item.base) << 16) | item.head, {});

                const node_count = try node_contexts.getOrPut(item.node);
                if (!node_count.found_existing) node_count.value_ptr.* = 0;
                node_count.value_ptr.* += 1;

                if (deck.isEmpty()) {
                    empty += 1;
                    frontier_buckets[0] += 1;
                    continue;
                }
                if (deck.isCope()) {
                    thunks += 1;
                    continue;
                }
                try frontier_roots.put(deck, {});

                const len = deck.duelCount();
                frontier_cells += len;
                frontier_max = @max(frontier_max, len);
                frontier_buckets[distributionBucket(len)] += 1;
            }

            var node_iter = node_contexts.valueIterator();
            var contexts_max: usize = 0;
            while (node_iter.next()) |count| {
                contexts_max = @max(contexts_max, count.*);
                context_buckets[distributionBucket(count.*)] += 1;
            }

            const entries = this.memo.count();
            const unique_nodes = node_contexts.count();
            const load = if (this.memo.capacity() == 0)
                0
            else
                100.0 * @as(f64, @floatFromInt(entries)) /
                    @as(f64, @floatFromInt(this.memo.capacity()));
            const contexts_average = if (unique_nodes == 0)
                0
            else
                @as(f64, @floatFromInt(entries)) / @as(f64, @floatFromInt(unique_nodes));
            const frontier_count = entries - empty - thunks;
            const frontier_average = if (frontier_count == 0)
                0
            else
                @as(f64, @floatFromInt(frontier_cells)) /
                    @as(f64, @floatFromInt(frontier_count));
            std.debug.print(
                "memo table: entries={d} capacity={d} load={d:.1}% key={d}B value={d}B\n",
                .{
                    entries,
                    this.memo.capacity(),
                    load,
                    @sizeOf(Item),
                    @sizeOf(Deck),
                },
            );
            std.debug.print(
                "  keys: hcat={d} fork={d} nodes={d} context_pairs={d} head_max={d} base_max={d}\n",
                .{ tags[@intFromEnum(Tag.hcat)], tags[@intFromEnum(Tag.fork)], unique_nodes, contexts.count(), head_max, base_max },
            );
            std.debug.print(
                "  contexts/node [1,2,3-4,5-8,9-16,17+]={any} avg={d:.2} max={d}\n",
                .{ context_buckets[1..], contexts_average, contexts_max },
            );
            std.debug.print(
                "  context regions [<=width,<=1.2*width,beyond]: entries={any} hits={any} misses={any}\n",
                .{ entry_regions, this.memo_hit_regions, this.memo_miss_regions },
            );
            std.debug.print(
                "  values: empty={d} thunks={d} distinct_roots={d} referenced_cells={d} avg={d:.2} max={d}\n",
                .{
                    empty,
                    thunks,
                    frontier_roots.count(),
                    frontier_cells,
                    frontier_average,
                    frontier_max,
                },
            );
            std.debug.print(
                "  frontier lengths [0,1,2,3-4,5-8,9-16,17+]={any}\n",
                .{frontier_buckets},
            );
        }

        fn explore(this: *@This()) !void {
            while (true) {
                switch (this.exec.tick) {
                    .give => |deck| {
                        if (this.exec.then.kind == .none) {
                            if (deck.isCope()) {
                                try this.forceCope(deck);
                                continue;
                            }

                            for (0..deck.duelCount()) |i| {
                                const duel = deck.candidate(i, this.heap);
                                try this.meld(.{ .gist = duel.gist, .node = duel.node });
                            }
                            break;
                        }
                    },
                    else => {},
                }

                if (build_options.profile_outline)
                    try @call(.never_inline, step, .{this})
                else
                    try this.step();

                this.gc_poll +%= 1;
                if (this.gc_poll == 0) try this.fuss();
            }
        }

        /// Frontier manipulation helpers
        /// Create a singleton frontier from one idea
        fn singleton(this: *@This(), node: Node, gist: Gist) !Deck {
            const idx = try this.heap.new().duel.push(this.heap.bank, .{ .node = node, .gist = gist });
            return Deck.one(this.heap.tick, @intCast(idx));
        }

        fn delay(this: *@This(), node: Node, crux: Crux) !Deck {
            var forced = crux;
            forced.icky = 1;
            const idx = try this.heap.new().cope.push(this.heap.bank, .{
                .node = node,
                .crux = forced,
            });
            if (comptime collect_statistics) this.stat.cope_deferred += 1;
            return Deck.thunk(this.heap.tick, @intCast(idx));
        }

        fn resumeCope(this: *@This(), deck: Deck) void {
            std.debug.assert(deck.isCope());
            const cope = this.heap.new().cope.list.items[deck.copeItem()];
            if (comptime collect_statistics) this.stat.cope_forced += 1;
            this.exec.node = cope.node;
            this.exec.tick = .{ .eval = cope.crux };
        }

        fn forceCope(this: *@This(), deck: Deck) !void {
            const then = this.exec.then;
            this.exec.then = try Ktx2.make(.{ .then = then }, this.heap);
            this.resumeCope(deck);
        }

        fn parentCrux(item: Item, origin_base: u15) Crux {
            return .{ .last = item.head, .base = origin_base };
        }

        fn terminalExceedsLimit(this: *@This(), node: Node, crux: Crux) bool {
            var column: u32 = crux.last;
            if (column > this.limit or crux.base > this.limit) return true;

            return switch (node.look()) {
                .rune => |rune| blk: {
                    if (rune.code == '\n') break :blk false;
                    const width = std.unicode.utf8CodepointSequenceLength(rune.code) catch 1;
                    column += @as(u32, width) * rune.reps;
                    break :blk column > this.limit;
                },
                .span => |span| blk: {
                    if (span.char != 0 and span.side == .lchr) {
                        if (span.char == '\n')
                            column = crux.base
                        else
                            column += 1;
                        if (column > this.limit) break :blk true;
                    }
                    const text = std.mem.sliceTo(this.tree.blob.items[span.text..], 0);
                    column += @intCast(text.len);
                    if (column > this.limit) break :blk true;
                    if (span.char != 0 and span.side == .rchr) {
                        if (span.char == '\n')
                            column = crux.base
                        else
                            column += 1;
                    }
                    break :blk column > this.limit;
                },
                .quad => |quad| blk: {
                    for ([_]u7{ quad.ch0, quad.ch1, quad.ch2, quad.ch3 }) |char| {
                        if (char == 0) break;
                        if (char == '\n')
                            column = crux.base
                        else
                            column += 1;
                        if (column > this.limit) break :blk true;
                    }
                    break :blk false;
                },
                .trip => |trip| blk: {
                    const glyph = trip.slice();
                    for (0..trip.repeatCount()) |_| {
                        for (glyph[0..trip.unitLen()]) |char| {
                            if (char == '\n')
                                column = crux.base
                            else
                                column += 1;
                            if (column > this.limit) break :blk true;
                        }
                    }
                    break :blk false;
                },
                .hcat, .fork, .cons => column > this.limit or crux.base > this.limit,
            };
        }

        /// Merge two frontiers, keeping only pareto-optimal ideas (OCaml-style)
        fn merge_decks(this: *@This(), a: Deck, b: Deck) !Deck {
            // OCaml merge: iterate both lists, keeping non-dominated ideas
            // If m1 <== m2: skip m2, keep m1
            // Else if m2 <== m1: skip m1, keep m2
            // Else: keep both and continue based on last
            //
            // Cope handling (OCaml's Tainted):
            // - Prefer Duel (frontier) over Cope (thunk)
            // - If both Cope, pick either one

            if (a.isEmpty()) return b;
            if (b.isEmpty()) return a;

            // If b is Cope, prefer a (might be Duel or Cope)
            if (b.isCope()) return a;
            // If a is Cope (and b is Duel), prefer b
            if (a.isCope()) return b;

            // Both are Duel frontiers, merge them

            var result = Deck.none;
            var a_pos: usize = 0;
            var b_pos: usize = 0;

            while (a_pos < a.duelCount() or b_pos < b.duelCount()) {
                if (a_pos == a.duelCount()) {
                    // Only b left
                    const b_duel = b.candidate(b_pos, this.heap);
                    result = try this.cons_to_deck_raw(result, b_duel.node, b_duel.gist);
                    b_pos += 1;
                    continue;
                }
                if (b_pos == b.duelCount()) {
                    // Only a left
                    const a_duel = a.candidate(a_pos, this.heap);
                    result = try this.cons_to_deck_raw(result, a_duel.node, a_duel.gist);
                    a_pos += 1;
                    continue;
                }

                const a_duel = a.candidate(a_pos, this.heap);
                const b_duel = b.candidate(b_pos, this.heap);

                if (wins(this.cost, a_duel.gist, b_duel.gist)) {
                    // a dominates b, skip b
                    b_pos += 1;
                } else if (wins(this.cost, b_duel.gist, a_duel.gist)) {
                    // b dominates a, skip a
                    a_pos += 1;
                } else if (a_duel.gist.last > b_duel.gist.last) {
                    // Neither dominates, emit a (higher last)
                    result = try this.cons_to_deck_raw(result, a_duel.node, a_duel.gist);
                    a_pos += 1;
                } else {
                    // Neither dominates, emit b (higher or equal last)
                    result = try this.cons_to_deck_raw(result, b_duel.node, b_duel.gist);
                    b_pos += 1;
                }
            }

            // We prepend above, but frontiers must be ordered by decreasing `last`.
            return try this.reverse_deck(result);
        }

        /// Prepend an idea without a dominance check.
        fn cons_to_deck_raw(this: *@This(), deck: Deck, node: Node, gist: Gist) !Deck {
            if (deck.isCope() or deck.duelCount() >= 2)
                @panic("Pareto frontier exceeds the two-Duel Deck capacity");
            if (deck.isEmpty()) return this.singleton(node, gist);
            const idx = try this.heap.new().duel.push(this.heap.bank, .{
                .node = node,
                .gist = gist,
            });
            return Deck.two(this.heap.tick, @intCast(idx), deck.duelItem(0));
        }

        fn reverse_deck(_: *@This(), deck: Deck) !Deck {
            std.debug.assert(!deck.isCope());
            return deck.reversed();
        }

        /// Preserve a choice node's local indentation modifier after eliminating
        /// the choice itself from every resolved layout.
        fn wrap_deck(this: *@This(), deck: Deck, frob: Frob) !Deck {
            if (deck.isEmpty() or (frob.warp == 0 and frob.nest == 0))
                return deck;

            std.debug.assert(!deck.isCope());
            var reversed = Deck.none;
            for (0..deck.duelCount()) |i| {
                const duel = deck.candidate(i, this.heap);
                const node = try this.tree.cons(frob, duel.node, Node.halt);
                reversed = try this.cons_to_deck_raw(reversed, node, duel.gist);
            }
            return try this.reverse_deck(reversed);
        }

        /// Helper: emit a node to a string buffer for debugging
        /// Returns a preview of what this node produces (truncated if too long)
        fn preview(this: *@This(), node: Node) []const u8 {
            var buf: [128]u8 = undefined;
            var writer = std.Io.Writer.fixed(&buf);
            this.tree.emit(&writer, node) catch return "<emit-error>";
            const s = writer.buffered();
            // Escape newlines and show preview
            if (std.mem.indexOfScalar(u8, s, '\n')) |_| {
                return "<multiline>";
            }
            if (s.len > 40) {
                return s[0..37] ++ "...";
            }
            return s;
        }

        /// Calculate continuation depth for indentation
        fn contDepth(this: *@This(), exec: Exec) usize {
            var depth: usize = 0;
            var ktx = exec.then;
            while (ktx.kind != .none) {
                depth += 1;
                const loaded = ktx.load(this.heap);
                ktx = switch (loaded) {
                    .empty => unreachable,
                    .head => |k| k.then,
                    .tail => |k| k.then,
                    .fork => |k| k.then,
                    .iter => |k| k.then,
                    .memo => |k| k.then,
                };
            }
            return depth;
        }

        /// Advance the CEK machine by a single step.
        pub fn step(this: *@This()) !void {
            switch (this.exec.tick) {
                .eval => |eval| {
                    // We are about to evaluate a node.
                    var crux = eval;

                    if (crux.icky == 0 and this.terminalExceedsLimit(this.exec.node, crux)) {
                        @branchHint(.unlikely);
                        this.exec.tick = .{ .give = try this.delay(this.exec.node, crux) };
                        return;
                    }

                    switch (this.exec.node.look()) {
                        .rune => |rune| {
                            const gist = rune.toGist(crux, this.cost);
                            this.exec.tick = .{ .give = try this.singleton(this.exec.node, gist) };
                            return;
                        },
                        .span => |span| {
                            const gist = span.toGist(crux, this.cost, this.tree);
                            this.exec.tick = .{ .give = try this.singleton(this.exec.node, gist) };
                            return;
                        },
                        .quad => |quad| {
                            const gist = quad.toGist(crux, this.cost);
                            this.exec.tick = .{ .give = try this.singleton(this.exec.node, gist) };
                            return;
                        },
                        .trip => |trip| {
                            const gist = trip.toGist(crux, this.cost);
                            this.exec.tick = .{ .give = try this.singleton(this.exec.node, gist) };
                            return;
                        },
                        .hcat => |oper| {
                            const hcat = this.heap.new().hcat.list.items[oper.item];
                            const origin = crux;

                            // Apply local indent state to the crux.
                            if (oper.frob.warp == 1) crux.warp();
                            if (oper.frob.nest != 0) crux.nest(oper.frob.nest);

                            const then = this.exec.then;
                            const item = crux.item(this.exec.node);

                            if (hcat.head == Node.memo_mark) {
                                @branchHint(.unlikely);
                                const memoize_node = this.memoize and
                                    crux.icky == 0 and
                                    crux.last <= this.limit and
                                    crux.base <= this.limit;
                                if (memoize_node) {
                                    if (this.memo.get(item)) |deck| {
                                        @branchHint(.unlikely);
                                        if (comptime collect_statistics) {
                                            this.stat.memo_hits += 1;
                                            this.stat.memo_hits_hcat += 1;
                                            if (this.trace_memo)
                                                this.memo_hit_regions[this.contextRegion(item)] += 1;
                                        }
                                        this.exec.tick = .{ .give = deck };
                                        return;
                                    }
                                    if (comptime collect_statistics) {
                                        this.stat.memo_misses += 1;
                                        this.stat.memo_misses_hcat += 1;
                                        if (this.trace_memo)
                                            this.memo_miss_regions[this.contextRegion(item)] += 1;
                                    }
                                }

                                this.exec.node = hcat.tail;
                                this.exec.tick = .{ .eval = crux };
                                this.exec.then = try Ktx5.make(.{
                                    .item = item,
                                    .frob = oper.frob,
                                    .origin_base = origin.base,
                                    .forced = origin.icky != 0,
                                    .store = memoize_node,
                                    .then = then,
                                }, this.heap);
                                return;
                            }

                            // We will start evaluating the hcat head.
                            this.exec.node = hcat.head;

                            // Splice the hcat task with the current continuation.
                            this.exec.then = try Ktx1.make(.{
                                // Afterwards, proceed with the hcat tail.
                                .node = hcat.tail,
                                // Use the same indent base.
                                .base = crux.base,
                                .origin_base = origin.base,
                                .forced = origin.icky != 0,
                                // After the hcat tail, return to the current continuation.
                                .then = then,
                                // Remember what item we are evaluating.
                                .item = item,
                            }, this.heap);

                            this.exec.tick = .{ .eval = crux };

                            return;
                        },
                        .fork => |fork| {
                            const pair = this.heap.new().fork.list.items[fork.item];
                            const origin = crux;

                            // Apply local indent state to the crux.
                            if (fork.frob.warp == 1) crux.warp();
                            if (fork.frob.nest != 0) crux.nest(fork.frob.nest);

                            const then = this.exec.then;
                            const item = crux.item(this.exec.node);

                            // Evaluate left branch first
                            this.exec.node = pair.head;
                            this.exec.tick = .{ .eval = crux };

                            // After left branch completes, we'll evaluate right branch
                            this.exec.then = try Ktx1.make(.{
                                .node = pair.tail,
                                .base = crux.base,
                                .origin_base = origin.base,
                                .forced = origin.icky != 0,
                                .item = item,
                                .then = then,
                            }, this.heap);

                            return;
                        },
                        .cons => unreachable,
                    }
                },
                .give => {
                    // We have evaluated a node to a gist and a forkless node.
                    // If there is a current continuation, inspect it to proceed.

                    switch (this.exec.then.load(this.heap)) {
                        .head => |cont| {
                            const left_deck = this.exec.tick.give;

                            if (left_deck.isCope() and cont.forced) {
                                @branchHint(.unlikely);
                                try this.forceCope(left_deck);
                                return;
                            }

                            // Check if this is a fork or hcat by examining the item node
                            const is_fork = cont.item.node.tag == .fork;

                            if (is_fork) {
                                if (cont.forced) {
                                    @branchHint(.unlikely);
                                    const oper = Node.view(Oper, cont.item.node);
                                    const result = try this.wrap_deck(left_deck, oper.frob);
                                    this.exec.tick = .{ .give = result };
                                    this.exec.then = cont.then;
                                    return;
                                }

                                // We have evaluated the left branch of a fork.
                                // Now evaluate the right branch.
                                this.exec.node = cont.node;

                                // After the right branch, we will merge and continue.
                                this.exec.then = try Ktx3.make(.{
                                    .item = cont.item,
                                    .then = cont.then,
                                    .left_deck = left_deck,
                                    .origin_base = cont.origin_base,
                                    .forced = cont.forced,
                                }, this.heap);

                                // Evaluate right branch with same context as left
                                this.exec.tick = .{
                                    .eval = .{
                                        .base = cont.base,
                                        .last = cont.item.head,
                                        .icky = @intFromBool(cont.forced),
                                    },
                                };

                                return;
                            } else {
                                // We have evaluated the head of a hcat.
                                const head_deck = left_deck;
                                const oper = Node.view(Oper, cont.item.node);

                                if (head_deck.isCope()) {
                                    @branchHint(.unlikely);
                                    this.exec.tick = .{ .give = try this.delay(
                                        cont.item.node,
                                        parentCrux(cont.item, cont.origin_base),
                                    ) };
                                    this.exec.then = cont.then;
                                    return;
                                }

                                // If head has no valid layouts, the whole hcat has none
                                if (head_deck.isEmpty()) {
                                    this.exec.tick = .{ .give = Deck.none };
                                    this.exec.then = cont.then;
                                    return;
                                }

                                // Set up iteration through head frontier
                                // We'll evaluate tail for each head, one at a time
                                this.exec.node = cont.node; // The tail node

                                // Create iterator continuation
                                this.exec.then = try Ktx4.make(.{
                                    .current_head = head_deck,
                                    .result_deck = Deck.none,
                                    .tail_node = cont.node,
                                    .item = cont.item,
                                    .base = cont.base,
                                    .frob = oper.frob,
                                    .origin_base = cont.origin_base,
                                    .forced = cont.forced,
                                    .then = cont.then,
                                }, this.heap);

                                // Evaluate tail starting at first head's ending position
                                const first_duel = head_deck.candidate(0, this.heap);

                                this.exec.tick = .{
                                    .eval = .{
                                        .base = cont.base,
                                        .last = first_duel.gist.last,
                                        .icky = @intFromBool(cont.forced and first_duel.gist.rows() == 0),
                                    },
                                };

                                return;
                            }
                        },
                        .iter => |cont| {
                            // Tail has been evaluated for current head
                            // Combine this (head, tail) pair and continue iteration
                            const tail_deck = this.exec.tick.give;

                            if (tail_deck.isCope() and cont.forced) {
                                @branchHint(.unlikely);
                                try this.forceCope(tail_deck);
                                return;
                            } else if (tail_deck.isCope()) {
                                @branchHint(.unlikely);
                                const delayed = try this.delay(
                                    cont.item.node,
                                    parentCrux(cont.item, cont.origin_base),
                                );
                                const merged = try this.merge_decks(cont.result_deck, delayed);
                                this.exec.then.load(this.heap).iter.result_deck = merged;
                            } else if (!tail_deck.isEmpty()) {
                                // If tail has no layouts, skip this head.
                                // Get current head Duel
                                const head_duel = cont.current_head.candidate(0, this.heap);
                                // Do "running best" scan through tail (like OCaml)
                                var partial_reversed = Deck.none;
                                var current_best: ?struct { gist: Gist, node: Node } = null;
                                for (0..tail_deck.duelCount()) |i| {
                                    const tail_duel = tail_deck.candidate(i, this.heap);
                                    const gist = combineGist(head_duel.gist, tail_duel.gist, this.cost);
                                    const node = try this.tree.cons(cont.frob, head_duel.node, tail_duel.node);

                                    if (current_best) |best| {
                                        if (cost_le(gist.rank, best.gist.rank)) {
                                            current_best = .{ .gist = gist, .node = node };
                                        } else {
                                            partial_reversed = try this.cons_to_deck_raw(
                                                partial_reversed,
                                                best.node,
                                                best.gist,
                                            );
                                            current_best = .{ .gist = gist, .node = node };
                                        }
                                    } else {
                                        current_best = .{ .gist = gist, .node = node };
                                    }
                                }

                                // Add final current_best
                                if (current_best) |best| {
                                    partial_reversed = try this.cons_to_deck_raw(
                                        partial_reversed,
                                        best.node,
                                        best.gist,
                                    );
                                }

                                // Merge this head's results with accumulated results
                                const partial = try this.reverse_deck(partial_reversed);
                                const foo = try this.merge_decks(cont.result_deck, partial);
                                this.exec.then.load(this.heap).iter.result_deck = foo;
                            }

                            // Move to next head
                            const next_head = cont.current_head.dropFirst();

                            if (next_head.isEmpty()) {
                                // No more heads - iteration complete
                                const result = this.exec.then.load(this.heap).iter.result_deck;
                                this.exec.tick = .{ .give = result };
                                this.exec.then = cont.then;
                                return;
                            } else {
                                // More heads - evaluate tail at next head's position
                                this.exec.then.load(this.heap).iter.current_head = next_head;
                                this.exec.node = cont.tail_node;

                                const next_head_duel = next_head.candidate(0, this.heap);

                                this.exec.tick = .{
                                    .eval = .{
                                        .base = cont.base,
                                        .last = next_head_duel.gist.last,
                                        .icky = @intFromBool(cont.forced and next_head_duel.gist.rows() == 0),
                                    },
                                };

                                return;
                            }
                        },
                        .tail => |cont| {
                            const forced = this.exec.tick.give;
                            if (forced.isCope()) {
                                @branchHint(.unlikely);
                                this.resumeCope(forced);
                                return;
                            }
                            std.debug.assert(!forced.isEmpty());
                            const chosen = forced.candidate(0, this.heap);
                            this.exec.tick = .{ .give = try this.singleton(chosen.node, chosen.gist) };
                            this.exec.then = cont.then;
                            return;
                        },
                        .fork => |cont| {
                            // We have evaluated both branches of a fork.
                            // Now merge the left and right frontiers.

                            const left_deck = cont.left_deck;
                            const right_deck = this.exec.tick.give;

                            // Merge the two frontiers
                            const merged = try this.merge_decks(left_deck, right_deck);
                            const oper = Node.view(Oper, cont.item.node);
                            const result = if (merged.isCope())
                                try this.delay(
                                    cont.item.node,
                                    parentCrux(cont.item, cont.origin_base),
                                )
                            else
                                try this.wrap_deck(merged, oper.frob);

                            this.exec = .{
                                .tick = .{ .give = result },
                                .node = Node.halt,
                                .then = cont.then,
                            };

                            return;
                        },
                        .memo => |cont| {
                            const child = this.exec.tick.give;
                            if (child.isCope() and cont.forced) {
                                try this.forceCope(child);
                                return;
                            }

                            const result = if (child.isCope())
                                try this.delay(
                                    cont.item.node,
                                    parentCrux(cont.item, cont.origin_base),
                                )
                            else
                                try this.wrap_deck(child, cont.frob);

                            if (cont.store)
                                try this.memo.put(cont.item, result);
                            this.exec.tick = .{ .give = result };
                            this.exec.then = cont.then;
                            return;
                        },
                        .none => {},
                    }
                },

                // TODO: the dense node representation allows shortcuts.
                //
                // When A and B are tiny texts, A + B is often also a tiny text.
            }
        }

        fn cost_le(a: Rank, b: Rank) bool {
            return a.toU64() <= b.toU64();
        }

        fn wins(_: Cost, a: Gist, b: Gist) bool {
            // OCaml's <== compares the final column and the cost factory's total
            // cost order. Equality keeps the first measure and deduplicates it.
            return a.last <= b.last and cost_le(a.rank, b.rank);
        }

        fn meld(this: *@This(), idea: Idea) !void {
            var i: usize = 0;
            while (i < this.best.items.len) {
                const item = this.best.items[i];
                if (wins(this.cost, item.gist, idea.gist)) return;
                if (wins(this.cost, idea.gist, item.gist)) _ = this.best.swapRemove(i);
                i += 1;
            }

            try this.best.append(this.tree.bank, idea);
            if (comptime collect_statistics) this.stat.completions += 1;
        }

        fn debugLayout(this: *@This(), label: []const u8, gist: Gist, node: Node) void {
            var storage: [8192]u8 = undefined;
            var writer = std.Io.Writer.fixed(storage[0..]);
            this.tree.emit(&writer, node) catch |err| {
                std.debug.print("{s} emit failed: {}\n", .{ label, err });
                return;
            };
            const rendered = writer.buffered();
            var max_line: usize = 0;
            var curr: usize = 0;
            var longest_slice: []const u8 = rendered;
            for (rendered, 0..) |c, i| {
                if (c == '\n') {
                    if (curr > max_line) {
                        max_line = curr;
                        const start = i - curr;
                        longest_slice = rendered[start..i];
                    }
                    curr = 0;
                } else {
                    curr += 1;
                }
            }
            if (curr > max_line) {
                const start = rendered.len - curr;
                longest_slice = rendered[start..];
                max_line = curr;
            }
            std.debug.print(
                "{s} gist(last={d}, rows={d}, overflow={d}) actual_max_line={d}\n",
                .{ label, gist.last, gist.rows(), gist.rank.o, max_line },
            );
            std.debug.print("{s} longest line: {s}\n", .{ label, longest_slice });
            std.debug.print("{s}{s}", .{ label, rendered });
        }

        fn combineGist(head: Gist, tail: Gist, cost: Cost) Gist {
            return .{
                .last = tail.last,
                .rank = cost.plus(head.rank, tail.rank),
            };
        }
    };
}

pub const Loop = struct {
    pub fn pick(tree: *Tree, bank: Bank, cost: Cost, node: Node) !Best {
        return EvalLoop(false).pick(tree, bank, cost, node, .{}, {});
    }

    pub fn pickWithOptions(
        tree: *Tree,
        bank: Bank,
        cost: Cost,
        node: Node,
        options: PickOptions,
    ) !Best {
        if (options.trace_gc or options.trace_memo) {
            var ignored: Stat = .{};
            return EvalLoop(true).pick(tree, bank, cost, node, options, &ignored);
        }
        return EvalLoop(false).pick(tree, bank, cost, node, options, {});
    }

    pub fn pickWithStatistics(
        tree: *Tree,
        bank: Bank,
        cost: Cost,
        node: Node,
        options: PickOptions,
        stat: *Stat,
    ) !Best {
        stat.* = .{};
        return EvalLoop(true).pick(tree, bank, cost, node, options, stat);
    }
};

pub const Crux = packed struct {
    last: u16 = 0,
    base: u15 = 0,
    icky: u1 = 0,

    pub fn warp(self: *@This()) void {
        self.base = @intCast(@min(self.last, std.math.maxInt(u15)));
    }

    pub fn nest(self: *@This(), indent: u6) void {
        if (indent == 0) return;
        const widened = @as(u32, self.base) + @as(u32, indent);
        const limit = @as(u32, std.math.maxInt(u15));
        self.base = @intCast(@min(widened, limit));
    }

    pub fn item(self: @This(), node: Node) Item {
        return .{
            .base = self.base,
            .head = self.last,
            .node = node,
        };
    }
};

pub const Idea = packed struct {
    node: Node = Node.halt,
    gist: Gist = .{},

    pub fn warp(idea: Idea, heap: *Heap) !Idea {
        return .{
            .node = try idea.node.warp(heap),
            .gist = idea.gist,
        };
    }
};

pub const Cope = struct {
    node: Node,
    crux: Crux,

    pub fn warp(cope: Cope, heap: *Heap) !Cope {
        return .{
            .node = try cope.node.warp(heap),
            .crux = cope.crux,
        };
    }

    pub fn drag(cope: *Cope, heap: *Heap) !void {
        try heap.move(&cope.node);
    }
};

pub const Gist = packed struct {
    last: u16 = 0,
    rank: Rank = .{},

    pub fn rows(gist: Gist) u16 {
        return gist.rank.h;
    }
};

test "core evaluator records stay compact" {
    try std.testing.expectEqual(32, @bitSizeOf(Crux));
    try std.testing.expectEqual(4, @sizeOf(Crux));
    try std.testing.expectEqual(48, @bitSizeOf(Rank));
    try std.testing.expectEqual(8, @sizeOf(Rank));
    try std.testing.expectEqual(64, @bitSizeOf(Gist));
    try std.testing.expectEqual(8, @sizeOf(Gist));
    try std.testing.expectEqual(8, @sizeOf(Item));
    try std.testing.expectEqual(8, @sizeOf(Cope));
    try std.testing.expectEqual(16, @sizeOf(Idea));
    try std.testing.expectEqual(24, @sizeOf(Exec));
    try std.testing.expectEqual(24, @sizeOf(Ktx1));
    try std.testing.expectEqual(8, @sizeOf(Ktx2));
    try std.testing.expectEqual(24, @sizeOf(Ktx3));
    try std.testing.expectEqual(40, @sizeOf(Ktx4));
    try std.testing.expectEqual(24, @sizeOf(Ktx5));
    try std.testing.expectEqual(8, @sizeOf(Pair));
    try std.testing.expectEqual(16, @sizeOf(Duel));
    try std.testing.expectEqual(8, @sizeOf(Deck));
    try std.testing.expectEqual(16, @sizeOf(Best));
    try std.testing.expect(@sizeOf(EvalLoop(false)) < @sizeOf(EvalLoop(true)));
}

test "narrow indentation base saturates" {
    var crux: Crux = .{ .last = std.math.maxInt(u16) };
    crux.warp();
    try std.testing.expectEqual(std.math.maxInt(u15), crux.base);
    crux.nest(std.math.maxInt(u6));
    try std.testing.expectEqual(std.math.maxInt(u15), crux.base);
}

pub const Exec = struct {
    node: Node,
    tick: union(enum) {
        eval: Crux,
        give: Deck,
    },
    then: Kont = Kont.none,

    pub fn warp(exec: Exec, heap: *Heap) !Exec {
        return .{
            .node = try exec.node.warp(heap),
            .tick = switch (exec.tick) {
                .eval => exec.tick,
                .give => |deck| .{ .give = try deck.warp(heap) },
            },
            .then = try exec.then.warp(heap),
        };
    }
};

pub const Item = packed struct {
    node: Node,
    head: u16,
    base: u16,

    pub fn warp(item: Item, heap: *Heap) !Item {
        return .{
            .node = try item.node.warp(heap),
            .head = item.head,
            .base = item.base,
        };
    }
};

fn mixHash(word: u64) u64 {
    const mixed = word *% 0x9e3779b97f4a7c15;
    return mixed ^ (mixed >> 29);
}

const ItemHashContext = struct {
    pub fn hash(_: @This(), item: Item) u64 {
        return mixHash(@bitCast(item));
    }

    pub fn eql(_: @This(), a: Item, b: Item) bool {
        return a == b;
    }
};

const NodeHashContext = struct {
    pub fn hash(_: @This(), node: Node) u64 {
        return mixHash(node.repr());
    }

    pub fn eql(_: @This(), a: Node, b: Node) bool {
        return a == b;
    }
};

pub const Memo = std.HashMap(Item, Deck, ItemHashContext, 80);
const FlatMemo = std.HashMap(Node, Node, NodeHashContext, 80);

pub const Kont = packed struct {
    pub const Kind = enum(u3) { none, head, tail, fork, iter, memo };

    kind: Kind = .none,
    flip: u1 = 0,
    item: u28 = 0,

    pub const none: Kont = .{ .kind = .none, .flip = 1 };

    pub fn make(kind: Kind, flip: u1, idx: u28) Kont {
        return .{ .kind = kind, .flip = flip, .item = idx };
    }

    pub fn calm(this: Kont, flap: u1) bool {
        return this.flip == flap;
    }

    pub fn load(this: Kont, heap: *Heap) union(enum) { head: *Ktx1, tail: *Ktx2, fork: *Ktx3, iter: *Ktx4, memo: *Ktx5, none } {
        return switch (this.kind) {
            .head => .{ .head = &heap.new().ktx1.list.items[this.item] },
            .tail => .{ .tail = &heap.new().ktx2.list.items[this.item] },
            .fork => .{ .fork = &heap.new().ktx3.list.items[this.item] },
            .iter => .{ .iter = &heap.new().ktx4.list.items[this.item] },
            .memo => .{ .memo = &heap.new().ktx5.list.items[this.item] },
            .none => .none,
        };
    }

    pub fn warp(
        word: Kont,
        heap: *Heap,
    ) !Kont {
        if (word.calm(heap.tick)) return word;
        const next = switch (word.kind) {
            .head => try heap.copy(Ktx1, &heap.old().ktx1, &heap.new().ktx1, word.item),
            .tail => try heap.copy(Ktx2, &heap.old().ktx2, &heap.new().ktx2, word.item),
            .fork => try heap.copy(Ktx3, &heap.old().ktx3, &heap.new().ktx3, word.item),
            .iter => try heap.copy(Ktx4, &heap.old().ktx4, &heap.new().ktx4, word.item),
            .memo => try heap.copy(Ktx5, &heap.old().ktx5, &heap.new().ktx5, word.item),
            else => return word,
        };
        return word.onto(@intCast(next));
    }

    pub fn onto(this: Kont, unit: u21) Kont {
        var that = this;
        that.item = unit;
        that.flip ^= 1;
        return that;
    }
};

pub const Ktx1 = struct {
    node: Node,
    base: u15,
    origin_base: u15,
    forced: bool,
    item: Item,
    then: Kont,

    pub fn make(k1: Ktx1, heap: *Heap) !Kont {
        const idx = try heap.new().ktx1.push(heap.bank, k1);
        return Kont.make(.head, heap.tick, @intCast(idx));
    }

    pub fn drag(k1: *Ktx1, heap: *Heap) !void {
        try heap.move(&k1.node);
        try heap.move(&k1.item.node);
        try heap.move(&k1.then);
    }
};

pub const Ktx2 = struct {
    then: Kont,
    _forwarding: u32 = 0,

    pub fn make(k2: Ktx2, heap: *Heap) !Kont {
        const idx = try heap.new().ktx2.push(heap.bank, k2);
        return Kont.make(.tail, heap.tick, @intCast(idx));
    }

    pub fn drag(k2: *Ktx2, heap: *Heap) !void {
        try heap.move(&k2.then);
    }
};

pub const Ktx3 = struct {
    left_deck: Deck,
    origin_base: u15,
    forced: bool,
    item: Item,
    then: Kont,

    pub fn make(k3: Ktx3, heap: *Heap) !Kont {
        const idx = try heap.new().ktx3.push(heap.bank, k3);
        return Kont.make(.fork, heap.tick, @intCast(idx));
    }

    pub fn drag(k3: *Ktx3, heap: *Heap) !void {
        try heap.move(&k3.left_deck);
        try heap.move(&k3.item.node);
        try heap.move(&k3.then);
    }
};

pub const Ktx4 = struct {
    current_head: Deck, // Current position in head frontier iteration
    result_deck: Deck, // Accumulated results
    tail_node: Node, // Tail to evaluate for each head
    item: Item, // For memoization
    base: u15, // Indentation base
    frob: Frob, // Operator frob from hcat
    origin_base: u15,
    forced: bool,
    then: Kont, // Outer continuation

    pub fn make(k4: Ktx4, heap: *Heap) !Kont {
        const idx = try heap.new().ktx4.push(heap.bank, k4);
        return Kont.make(.iter, heap.tick, @intCast(idx));
    }

    pub fn drag(k4: *Ktx4, heap: *Heap) !void {
        try heap.move(&k4.current_head);
        try heap.move(&k4.result_deck);
        try heap.move(&k4.tail_node);
        try heap.move(&k4.item.node);
        try heap.move(&k4.then);
    }
};

pub const Ktx5 = struct {
    item: Item,
    frob: Frob,
    origin_base: u15,
    forced: bool,
    store: bool,
    then: Kont,

    pub fn make(k5: Ktx5, heap: *Heap) !Kont {
        const idx = try heap.new().ktx5.push(heap.bank, k5);
        return Kont.make(.memo, heap.tick, @intCast(idx));
    }

    pub fn drag(k5: *Ktx5, heap: *Heap) !void {
        try heap.move(&k5.item.node);
        try heap.move(&k5.then);
    }
};

/// Cost metric selection - either F1 (linear overflow) or F2 (squared overflow).
pub const Cost = union(enum) {
    f1: u16, // page width
    f2: u16, // page width

    pub fn width(self: Cost) u16 {
        return switch (self) {
            inline else => |page_width| page_width,
        };
    }

    pub fn defaultComputationWidth(self: Cost) u16 {
        const page_width = self.width();
        return page_width +| page_width / 5;
    }

    pub fn plus(_: Cost, lhs: Rank, rhs: Rank) Rank {
        return .{
            .h = lhs.h +| rhs.h,
            .o = lhs.o +| rhs.o,
        };
    }

    pub fn line(_: Cost) Rank {
        return .{ .h = 1 };
    }

    pub fn text(self: Cost, c: u16, l: u16) Rank {
        return switch (self) {
            .f1 => |w| .{
                .o = (c +| l) -| @max(w, c),
            },
            .f2 => |w| blk: {
                const a = @max(w, c) -| w;
                const b = (c +| l) -| @max(w, c);
                break :blk .{
                    .o = b *| (2 *| a +| b),
                };
            },
        };
    }

    pub fn wins(_: Cost, a: Rank, b: Rank) bool {
        // Lexicographic comparison for running-best scan
        return a.toU64() < b.toU64();
    }

    pub fn icky(_: Cost, rank: Rank) bool {
        return rank.o != 0;
    }
};

pub const Rank = packed struct {
    /// the sum of overflows (F1: linear, F2: squared)
    o: u32 = 0,
    /// the number of newlines
    h: u16 = 0,

    pub fn toU64(self: Rank) u64 {
        return @as(u64, self.o) << 16 | self.h;
    }

    pub fn bump(this: *Rank, that: Rank, cost: Cost) void {
        const both = cost.plus(this.*, that);
        this.* = both;
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

pub const Stat = struct {
    peak: usize = 0,
    completions: usize = 0,
    memo_hits: usize = 0,
    memo_misses: usize = 0,
    memo_hits_hcat: usize = 0,
    memo_hits_fork: usize = 0,
    memo_misses_hcat: usize = 0,
    memo_misses_fork: usize = 0,
    memo_entries: usize = 0,
    size: usize = 0,
    gc_count: usize = 0,
    gc_before_peak: usize = 0,
    gc_live_peak: usize = 0,
    gc_live_last: usize = 0,
    gc_copied_total: usize = 0,
    heap_peak: usize = 0,
    cope_deferred: usize = 0,
    cope_forced: usize = 0,
};

pub const PickOptions = struct {
    gc_tide: usize = 100_000_000,
    computation_width: ?u16 = null,
    trace_gc: bool = false,
    trace_memo: bool = false,
    memoize: bool = true,
};

pub const Best = struct {
    idea: Idea,
};

/// Example 3.4. in *A Pretty Expressive Printer*.
///
/// > Consider an optimality objective that minimizes the sum of overflows
/// > (the number of characters that exceed a given page width limit 𝑤 in each line),
/// > and then minimizes the height (the total number of newline characters,
/// > or equivalently, the number of lines minus one).
pub const F1 = struct {
    pub fn init(w: u16) Cost {
        return .{ .f1 = w };
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
    pub fn init(w: u16) Cost {
        return .{ .f2 = w };
    }
};

test "Cost F1 overflow includes current column" {
    const cf = F1.init(60);
    const rank = cf.text(50, 20);
    try std.testing.expectEqual(@as(u32, 10), rank.o);
}

test "Cost F2 overflow includes current column" {
    const cf = F2.init(60);
    const rank = cf.text(50, 20);
    try std.testing.expect(rank.o > 0);
}

pub const Tag = enum(u3) {
    span = 0b000,
    quad = 0b001,
    trip = 0b010,
    rune = 0b011,
    hcat = 0b100,
    fork = 0b101,
    cons = 0b110,
};

pub const Side = enum(u1) { lchr, rchr };

pub const Span = packed struct {
    tag: Tag = .span,
    side: Side = .lchr,
    char: u7 = 0,
    text: u21 = 0,

    pub fn toGist(self: Span, crux: Crux, cost: Cost, tree: *const Tree) Gist {
        var head = crux.last;
        var rank: Rank = .{};

        if (self.char != 0 and self.side == .lchr) {
            if (self.char == '\n') {
                head = crux.base;
                rank.bump(cost.line(), cost);
            } else {
                rank.bump(cost.text(head, 1), cost);
                head +|= 1;
            }
        }

        const tail = tree.blob.items[self.text..];
        const text = std.mem.sliceTo(tail, 0);
        const text_len: u16 = @intCast(text.len);
        if (text_len != 0) {
            rank.bump(cost.text(head, text_len), cost);
            head +|= text_len;
        }

        if (self.char != 0 and self.side == .rchr) {
            if (self.char == '\n') {
                rank.bump(cost.line(), cost);
                head = crux.base;
            } else {
                rank.bump(cost.text(head, 1), cost);
                head +|= 1;
            }
        }

        return .{
            .last = head,
            .rank = rank,
        };
    }
};

pub const Quad = packed struct {
    tag: Tag = .quad,
    pad: u1 = 0,
    ch0: u7 = 0,
    ch1: u7 = 0,
    ch2: u7 = 0,
    ch3: u7 = 0,

    pub fn toGist(self: Quad, crux: Crux, cost: Cost) Gist {
        var head = crux.last;
        var rank: Rank = .{};
        const chars = [_]u7{ self.ch0, self.ch1, self.ch2, self.ch3 };
        for (chars) |c| {
            if (c == 0) break;
            if (c == '\n') {
                head = crux.base;
                rank.bump(cost.line(), cost);
            } else {
                rank.bump(cost.text(head, 1), cost);
                head +|= 1;
            }
        }
        return .{
            .last = head,
            .rank = rank,
        };
    }
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

    pub fn toGist(self: Trip, crux: Crux, cost: Cost) Gist {
        var head = crux.last;
        var rank: Rank = .{};

        const glyph = self.slice();
        const glyph_len = self.unitLen();
        const repeats = self.repeatCount();

        if (glyph_len != 0 and repeats != 0) {
            for (0..repeats) |_| {
                for (glyph[0..glyph_len]) |char| {
                    if (char == '\n') {
                        head = crux.base;
                        rank.bump(cost.line(), cost);
                    } else {
                        rank.bump(cost.text(head, 1), cost);
                        head +|= 1;
                    }
                }
            }
        }

        return .{
            .last = head,
            .rank = rank,
        };
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

    pub fn toGist(self: Rune, crux: Crux, cost: Cost) Gist {
        var last = crux.last;
        var rank: Rank = .{};

        if (self.reps != 0) {
            if (self.code == '\n') {
                last = crux.base;
                for (0..self.reps) |_| {
                    const line_cost = cost.line();
                    rank = cost.plus(rank, line_cost);
                }
            } else {
                const width_per = std.unicode.utf8CodepointSequenceLength(self.code) catch 1;
                const total: u32 = @intCast(@as(u32, width_per) * self.reps);
                const text_cost = cost.text(crux.last, @intCast(total));
                rank.bump(text_cost, cost);
                const widened = @as(u32, crux.last) + total;
                const limit = @as(u32, std.math.maxInt(u16));
                last = @intCast(@min(widened, limit));
            }
        }

        return .{
            .last = last,
            .rank = rank,
        };
    }
};

pub const Frob = packed struct {
    /// 1 means align result to current column
    warp: u1 = 0,
    /// apply nest(n, _) to result
    nest: u6 = 0,
};

pub const Oper = packed struct {
    kind: Tag = .hcat,
    frob: Frob = .{},
    flip: u1 = 0,
    item: u21 = 0,
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
    blob: std.ArrayList(u8),
    flatmemo: FlatMemo,

    pub fn init(bank: Bank) !Tree {
        return .{
            .bank = bank,
            .heap = try Heap.init(bank),
            .blob = .empty,
            .flatmemo = FlatMemo.init(bank),
        };
    }

    pub fn deinit(tree: *Tree) void {
        tree.heap.deinit();
        tree.blob.deinit(tree.bank);
        tree.flatmemo.deinit();
    }

    pub fn pick(tree: *Tree, bank: Bank, cost: Cost, node: Node) !Best {
        return try Loop.pick(tree, bank, cost, node);
    }

    pub fn pickWithOptions(
        tree: *Tree,
        bank: Bank,
        cost: Cost,
        node: Node,
        options: PickOptions,
    ) !Best {
        return try Loop.pickWithOptions(tree, bank, cost, node, options);
    }

    pub fn pickWithStatistics(
        tree: *Tree,
        bank: Bank,
        cost: Cost,
        node: Node,
        options: PickOptions,
        stat: *Stat,
    ) !Best {
        return try Loop.pickWithStatistics(tree, bank, cost, node, options, stat);
    }

    pub fn rank(
        tree: *Tree,
        cf: Cost,
        node: Node,
    ) !Rank {
        const outcome = try tree.pick(tree.bank, cf, node);
        return outcome.idea.gist.rank;
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
                    ctx.last = ctx.base;
                } else {
                    var buffer: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(rune.code, &buffer) catch unreachable;
                    for (0..rune.reps) |_| try sink.writeAll(buffer[0..len]);
                    ctx.last +|= @intCast(len * rune.reps);
                }
            },
            .span => |span| {
                if (span.char != 0 and span.side == .lchr)
                    try emitChar(sink, ctx, span.char);

                const tail = tree.blob.items[span.text..];
                const slice = std.mem.sliceTo(tail, 0);
                if (slice.len != 0) {
                    try sink.writeAll(slice);
                    ctx.last +|= @intCast(slice.len);
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
            .hcat => |oper| {
                const pair = tree.heap.new().hcat.list.items[oper.item];

                var child_ctx = ctx.*;
                if (oper.frob.warp == 1) child_ctx.warp();
                if (oper.frob.nest != 0) child_ctx.nest(oper.frob.nest);
                try tree.emitNode(sink, pair.head, &child_ctx);

                var right_ctx = child_ctx;
                try tree.emitNode(sink, pair.tail, &right_ctx);
                ctx.last = right_ctx.last;
            },
            .cons => |oper| {
                const pair = tree.heap.new().cons.list.items[oper.item];

                var child_ctx = ctx.*;
                if (oper.frob.warp == 1) child_ctx.warp();
                if (oper.frob.nest != 0) child_ctx.nest(oper.frob.nest);
                try tree.emitNode(sink, pair.head, &child_ctx);

                var right_ctx = child_ctx;
                try tree.emitNode(sink, pair.tail, &right_ctx);

                ctx.last = right_ctx.last;
            },
            .fork => return error.EmitEncounteredFork,
        }
    }

    fn emitChar(sink: *std.Io.Writer, ctx: *Crux, char: u8) !void {
        if (char == '\n') {
            try sink.writeByte('\n');
            if (ctx.base != 0)
                try sink.splatByteAll(' ', ctx.base);
            ctx.last = ctx.base;
        } else {
            try sink.writeByte(char);
            ctx.last +|= 1;
        }
    }

    fn hasNewline(tree: *Tree, doc: Node) bool {
        return switch (doc.look()) {
            .span => |span| span.char == '\n',
            .rune => |rune| rune.code == '\n' and rune.reps > 0,
            .quad, .trip => false,
            .hcat => |oper| blk: {
                const pair = tree.heap.new().hcat.list.items[oper.item];
                break :blk hasNewline(tree, pair.head) or hasNewline(tree, pair.tail);
            },
            .fork => |oper| blk: {
                const pair = tree.heap.new().fork.list.items[oper.item];
                break :blk hasNewline(tree, pair.head) or hasNewline(tree, pair.tail);
            },
            .cons => false,
        };
    }

    pub fn flat(tree: *Tree, doc: Node) !Node {
        switch (doc.look()) {
            .span => |span| {
                if (span.char != '\n') return doc;
                return Node.fromSpan(span.side, ' ', span.text);
            },
            .quad, .trip => return doc,
            .rune => |rune| {
                if (rune.code != '\n' or rune.reps == 0) return doc;
                return Node.fromRune(rune.reps, ' ');
            },
            .hcat, .fork => {},
            .cons => unreachable,
        }

        if (tree.flatmemo.get(doc)) |entry| return entry;

        const result = switch (doc.look()) {
            .hcat => |oper| blk: {
                const pair = tree.heap.new().hcat.list.items[oper.item];
                const tail = try tree.flat(pair.tail);
                if (pair.head == Node.memo_mark) {
                    var flat_frob = oper.frob;
                    flat_frob.nest = 0;
                    if (tail == pair.tail and flat_frob.nest == oper.frob.nest)
                        break :blk doc;
                    break :blk try tree.rawHcat(flat_frob, Node.memo_mark, tail);
                }

                const head = try tree.flat(pair.head);
                const changed =
                    head.repr() != pair.head.repr() or
                    tail.repr() != pair.tail.repr();

                // Discard nest when flattening (no newlines = no indentation needed)
                var flat_frob = oper.frob;
                flat_frob.nest = 0;

                if (!changed and flat_frob.nest == oper.frob.nest) break :blk doc;

                break :blk try tree.hcat(flat_frob, head, tail);
            },
            .fork => |oper| blk: {
                const pair = tree.heap.new().fork.list.items[oper.item];
                const head = try tree.flat(pair.head);
                const tail = try tree.flat(pair.tail);
                const changed =
                    head.repr() != pair.head.repr() or
                    tail.repr() != pair.tail.repr();
                if (!changed) break :blk doc;

                break :blk try tree.makePair(.fork, oper.frob, head, tail);
            },
            else => unreachable,
        };

        try tree.flatmemo.put(doc, result);
        return result;
    }

    fn combineGist(head: Gist, tail: Gist, cost: Cost) Gist {
        return .{
            .last = tail.last,
            .rank = cost.plus(head.rank, tail.rank),
        };
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
            .hcat, .fork => |oper| {
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
            .hcat, .fork => {
                var new = doc;
                switch (new.edit()) {
                    .hcat, .fork => |oper| oper.frob.warp = 1,
                    else => unreachable,
                }
                return new;
            },
            .cons => unreachable,
            .span, .quad, .trip, .rune => if (doc.isEmptyText())
                return doc
            else {
                const oper = try tree.plus(doc, try tree.text(""));

                // We need an `oper` to carry the `frob`.
                // If `plus` learns to fuse tiny texts,
                // we'll need to fix this path.
                std.debug.assert(oper.tag == .hcat);

                return try tree.warp(oper);
            },
        }
    }

    const initial_memo_weight: u3 = 6;

    fn calcMemoWeight(weight: u3) u3 {
        return if (weight == 0) initial_memo_weight else weight - 1;
    }

    fn memoWeight(tree: *Tree, node: Node) u3 {
        return switch (node.look()) {
            .hcat => |oper| blk: {
                const pair = tree.heap.new().hcat.list.items[oper.item];
                if (pair.head == Node.memo_mark) break :blk 0;
                break :blk @min(
                    calcMemoWeight(tree.memoWeight(pair.head)),
                    calcMemoWeight(tree.memoWeight(pair.tail)),
                );
            },
            // .fork => |oper| blk: {
            //     const pair = tree.heap.new().fork.list.items[oper.item];
            //     break :blk @min(
            //         calcMemoWeight(tree.memoWeight(pair.head)),
            //         calcMemoWeight(tree.memoWeight(pair.tail)),
            //     );
            // },
            else => initial_memo_weight,
        };
    }

    fn rawHcat(tree: *Tree, frob: Frob, lhs: Node, rhs: Node) !Node {
        const next: u21 = @intCast(try tree.heap.new().hcat.push(tree.bank, .{
            .head = lhs,
            .tail = rhs,
        }));
        return Node.fromOper(.hcat, frob, tree.heap.tick, next);
    }

    fn rawFork(tree: *Tree, frob: Frob, lhs: Node, rhs: Node) !Node {
        const next: u21 = @intCast(try tree.heap.new().fork.push(tree.bank, .{
            .head = lhs,
            .tail = rhs,
        }));
        return Node.fromOper(.fork, frob, tree.heap.tick, next);
    }

    fn makePair(tree: *Tree, tag: Tag, frob: Frob, lhs: Node, rhs: Node) !Node {
        std.debug.assert(tag == .hcat or tag == .fork);
        const node = switch (tag) {
            .hcat => try tree.rawHcat(frob, lhs, rhs),
            .fork => return try tree.rawFork(frob, lhs, rhs),
            else => unreachable,
        };
        const weight = @min(
            calcMemoWeight(tree.memoWeight(lhs)),
            calcMemoWeight(tree.memoWeight(rhs)),
        );
        if (weight != 0) return node;
        return tree.rawHcat(.{}, Node.memo_mark, node);
    }

    pub fn hcat(tree: *Tree, frob: Frob, lhs: Node, rhs: Node) !Node {
        return tree.makePair(.hcat, frob, lhs, rhs);
    }

    pub fn cons(tree: *Tree, frob: Frob, lhs: Node, rhs: Node) !Node {
        const len = tree.heap.new().cons.list.items.len;
        const next: u21 = @intCast(len);
        try tree.heap.new().cons.list.append(tree.bank, .{ .head = lhs, .tail = rhs });
        return Node.fromOper(.cons, frob, tree.heap.tick, next);
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

        return try tree.hcat(.{}, lhs, rhs);
    }

    pub fn fork(tree: *Tree, lhs: Node, rhs: Node) !Node {
        return tree.makePair(.fork, .{}, lhs, rhs);
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
        const start_len = tree.blob.items.len;

        // Format directly into the slab
        var slab = std.Io.Writer.Allocating.fromArrayList(
            tree.bank,
            &tree.blob,
        );
        try slab.writer.print(fmt ++ "\x00", args);

        // Now use text() which will do the deduplication logic for us
        tree.blob = slab.toArrayList();
        const written = tree.blob.items[start_len .. tree.blob.items.len - 1 :0];
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
            tree.blob.shrinkRetainingCapacity(start_len);
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
            if (std.mem.indexOf(u8, tree.blob.items, spanz)) |i|
                i
            else blk: {
                const next = tree.blob.items.len;
                try tree.blob.appendSlice(tree.bank, spanz);
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

pub const Pair = struct {
    head: Node,
    tail: Node,

    pub const halt: Pair = just(.halt);

    pub fn just(a: Node) Pair {
        return .{ .head = a, .tail = .halt };
    }

    pub fn drag(node: *Pair, heap: *Heap) !void {
        try heap.move(&node.head);
        try heap.move(&node.tail);
    }
};

/// A frontier containing at most two Duels, or a deferred Cope thunk.
pub const Deck = packed struct {
    flip: u1,
    cope: u1,
    len: u2,
    item: u30,
    item2: u30,

    pub const none: Deck = .{ .flip = 0, .cope = 0, .len = 0, .item = 0, .item2 = 0 };

    pub fn one(flip: u1, item: u30) Deck {
        return .{ .flip = flip, .cope = 0, .len = 1, .item = item, .item2 = 0 };
    }

    pub fn two(flip: u1, first: u30, second: u30) Deck {
        return .{ .flip = flip, .cope = 0, .len = 2, .item = first, .item2 = second };
    }

    pub fn thunk(flip: u1, item: u30) Deck {
        return .{ .flip = flip, .cope = 1, .len = 0, .item = item, .item2 = 0 };
    }

    pub fn isEmpty(deck: Deck) bool {
        return deck.cope == 0 and deck.len == 0;
    }

    pub fn isCope(deck: Deck) bool {
        return deck.cope == 1;
    }

    pub fn copeItem(deck: Deck) u30 {
        std.debug.assert(deck.isCope());
        return deck.item;
    }

    pub fn duelCount(deck: Deck) usize {
        std.debug.assert(!deck.isCope());
        return deck.len;
    }

    pub fn duelItem(deck: Deck, index: usize) u30 {
        std.debug.assert(!deck.isCope() and index < deck.len);
        return if (index == 0) deck.item else deck.item2;
    }

    pub fn candidate(deck: Deck, index: usize, heap: *Heap) Duel {
        return heap.new().duel.list.items[deck.duelItem(index)];
    }

    pub fn dropFirst(deck: Deck) Deck {
        std.debug.assert(!deck.isCope() and deck.len != 0);
        return if (deck.len == 1) none else one(deck.flip, deck.item2);
    }

    pub fn reversed(deck: Deck) Deck {
        return if (deck.len == 2) two(deck.flip, deck.item2, deck.item) else deck;
    }

    pub fn calm(deck: Deck, flap: u1) bool {
        return deck.isEmpty() or deck.flip == flap;
    }

    pub fn warp(deck: Deck, heap: *Heap) !Deck {
        if (deck.calm(heap.tick)) return deck;
        if (deck.isCope()) {
            const next = try heap.copy(Cope, &heap.old().cope, &heap.new().cope, deck.item);
            return thunk(heap.tick, @intCast(next));
        }
        const first = try heap.copy(Duel, &heap.old().duel, &heap.new().duel, deck.item);
        if (deck.len == 1) return one(heap.tick, @intCast(first));
        const second = try heap.copy(Duel, &heap.old().duel, &heap.new().duel, deck.item2);
        return two(heap.tick, @intCast(first), @intCast(second));
    }
};

/// One concrete candidate in a Pareto frontier.
pub const Duel = struct {
    node: Node, // The resolved (forkless) layout node
    gist: Gist, // The layout metrics (last column, rows, rank)

    pub const halt: Duel = .{ .node = .halt, .gist = .{} };

    pub fn drag(duel: *Duel, heap: *Heap) !void {
        try heap.move(&duel.node);
    }
};

test "Deck stores up to two Duel indices" {
    try std.testing.expectEqual(8, @sizeOf(Deck));
    try std.testing.expect(Deck.none.isEmpty());

    const one = Deck.one(1, 17);
    try std.testing.expectEqual(1, one.duelCount());
    try std.testing.expectEqual(17, one.duelItem(0));

    const two = Deck.two(1, 17, 23);
    try std.testing.expectEqual(2, two.duelCount());
    try std.testing.expectEqual(17, two.duelItem(0));
    try std.testing.expectEqual(23, two.duelItem(1));
    try std.testing.expectEqual(Deck.one(1, 23), two.dropFirst());
}

const Forwarding = extern struct {
    mark: u32,
    word: u32,
};

pub fn Rack(Elem: type) type {
    if (@sizeOf(Elem) < @sizeOf(Forwarding) or @alignOf(Elem) < @alignOf(Forwarding))
        @compileError("semispace cells need eight writable, four-byte-aligned bytes");

    return struct {
        list: std.ArrayList(Elem) = .empty,
        scan: usize = 0,

        pub const empty: @This() = .{};

        pub fn burn(rack: *@This(), item: usize, word: u32) void {
            const forwarding: *Forwarding = @ptrCast(&rack.list.items[item]);
            forwarding.* = .{ .mark = 0x13371337, .word = word };
        }

        pub fn look(rack: *@This(), item: usize) ?u32 {
            const forwarding: *const Forwarding = @ptrCast(&rack.list.items[item]);
            return if (forwarding.mark == 0x13371337) forwarding.word else null;
        }

        pub fn push(rack: *@This(), bank: Bank, elem: Elem) !u32 {
            const item = rack.list.items.len;

            try rack.list.append(bank, elem);
            return @intCast(item);
        }

        pub fn calm(rack: @This()) bool {
            return rack.scan == rack.list.items.len;
        }

        pub fn size(rack: @This()) usize {
            return rack.list.items.len * @sizeOf(Elem);
        }

        pub fn rift(rack: *@This()) []Elem {
            return rack.list.items[rack.scan..];
        }

        pub fn pull(this: *@This(), heap: *Heap) !void {
            while (this.scan < this.list.items.len) {
                const i = this.scan;
                // Copy out to avoid iterator invalidation during drag
                var elem = this.list.items[i];
                try elem.drag(heap);
                // Write back after drag completes
                this.list.items[i] = elem;
                this.scan += 1;
            }
        }

        pub fn deinit(rack: *@This(), bank: Bank) void {
            rack.list.deinit(bank);
        }

        pub fn clearRetainingCapacity(rack: *@This()) void {
            rack.list.clearRetainingCapacity();
            rack.scan = 0;
        }
    };
}

pub const Half = struct {
    hcat: Rack(Pair) = .empty,
    fork: Rack(Pair) = .empty,
    cons: Rack(Pair) = .empty,
    ktx1: Rack(Ktx1) = .empty,
    ktx2: Rack(Ktx2) = .empty,
    ktx3: Rack(Ktx3) = .empty,
    ktx4: Rack(Ktx4) = .empty,
    ktx5: Rack(Ktx5) = .empty,
    duel: Rack(Duel) = .empty,
    cope: Rack(Cope) = .empty,

    pub fn init(this: *@This(), bank: Bank) !void {
        try this.hcat.list.ensureTotalCapacity(bank, 4096);
        try this.fork.list.ensureTotalCapacity(bank, 4096);
        try this.cons.list.ensureTotalCapacity(bank, 4096);
        try this.ktx1.list.ensureTotalCapacity(bank, 4096);
        try this.ktx2.list.ensureTotalCapacity(bank, 4096);
        try this.ktx3.list.ensureTotalCapacity(bank, 4096);
        try this.ktx4.list.ensureTotalCapacity(bank, 4096);
        try this.ktx5.list.ensureTotalCapacity(bank, 4096);
        try this.duel.list.ensureTotalCapacity(bank, 4096);
        try this.cope.list.ensureTotalCapacity(bank, 4096);
    }

    pub fn deinit(this: *@This(), bank: Bank) void {
        this.hcat.deinit(bank);
        this.fork.deinit(bank);
        this.cons.deinit(bank);
        this.ktx1.deinit(bank);
        this.ktx2.deinit(bank);
        this.ktx3.deinit(bank);
        this.ktx4.deinit(bank);
        this.ktx5.deinit(bank);
        this.duel.deinit(bank);
        this.cope.deinit(bank);
    }

    pub fn clearRetainingCapacity(this: *@This()) void {
        this.hcat.clearRetainingCapacity();
        this.fork.clearRetainingCapacity();
        this.cons.clearRetainingCapacity();
        this.ktx1.clearRetainingCapacity();
        this.ktx2.clearRetainingCapacity();
        this.ktx3.clearRetainingCapacity();
        this.ktx4.clearRetainingCapacity();
        this.ktx5.clearRetainingCapacity();
        this.duel.clearRetainingCapacity();
        this.cope.clearRetainingCapacity();
    }

    pub fn calm(this: @This()) bool {
        return this.hcat.calm() and
            this.fork.calm() and
            this.cons.calm() and
            this.ktx1.calm() and
            this.ktx2.calm() and
            this.ktx3.calm() and
            this.ktx4.calm() and
            this.ktx5.calm() and
            this.duel.calm() and
            this.cope.calm();
    }

    pub fn size(this: @This()) usize {
        return this.hcat.size() + this.fork.size() + this.cons.size() +
            this.ktx1.size() + this.ktx2.size() + this.ktx3.size() + this.ktx4.size() +
            this.ktx5.size() +
            this.duel.size() + this.cope.size();
    }

    pub fn dump(this: @This()) void {
        std.debug.print(
            "hcat {Bi:>6.0} fork {Bi:>6.0} cons {Bi:>6.0} ktx1 {Bi:>6.0} ktx2 {Bi:>6.0} ktx3 {Bi:>6.0} ktx4 {Bi:>6.0} ktx5 {Bi:>6.0} duel {Bi:>6.0} cope {Bi:>6.0}\n",
            .{
                this.hcat.size(),
                this.fork.size(),
                this.cons.size(),
                this.ktx1.size(),
                this.ktx2.size(),
                this.ktx3.size(),
                this.ktx4.size(),
                this.ktx5.size(),
                this.duel.size(),
                this.cope.size(),
            },
        );
    }

    pub fn pull(this: *@This(), heap: *Heap) !void {
        try this.hcat.pull(heap);
        try this.fork.pull(heap);
        try this.cons.pull(heap);
        try this.ktx1.pull(heap);
        try this.ktx2.pull(heap);
        try this.ktx3.pull(heap);
        try this.ktx4.pull(heap);
        try this.ktx5.pull(heap);
        try this.duel.pull(heap);
        try this.cope.pull(heap);
    }
};

pub const Heap = struct {
    heap: [2]Half,
    tick: u1 = 0,
    bank: Bank,

    pub fn init(bank: Bank) !Heap {
        var me = Heap{ .heap = .{ .{}, .{} }, .tick = 0, .bank = bank };
        try me.heap[0].init(bank);
        try me.heap[1].init(bank);
        return me;
    }

    pub fn deinit(heap: *Heap) void {
        heap.heap[0].deinit(heap.bank);
        heap.heap[1].deinit(heap.bank);
    }

    pub fn new(heap: *Heap) *Half {
        return &heap.heap[heap.tick];
    }

    pub fn old(heap: *Heap) *Half {
        return &heap.heap[heap.tick ^ 1];
    }

    pub fn size(heap: *Heap) usize {
        return heap.new().size();
    }

    /// Begin GC: flip and clear new space
    pub fn flip(heap: *Heap) void {
        heap.tick ^= 1;
        heap.heap[heap.tick].clearRetainingCapacity();
    }

    pub fn move(heap: *Heap, thing: anytype) !void {
        thing.* = try thing.warp(heap);
    }

    /// Scan all unscanned items until fixed point
    pub fn scan(heap: *Heap) !void {
        while (!heap.new().calm()) {
            try heap.new().pull(heap);
        }
    }

    /// Rebuild hashmap by warping keys and values, keeping only reachable entries
    pub fn hash(heap: *Heap, old_map: anytype, new_map: anytype) !void {
        var iter = old_map.iterator();
        while (iter.next()) |entry| {
            const key = try entry.key_ptr.*.warp(heap);
            const value = try entry.value_ptr.*.warp(heap);
            try new_map.put(key, value);
        }
    }

    pub fn copy(
        heap: *Heap,
        comptime T: type,
        from: *Rack(T),
        dest: *Rack(T),
        item: usize,
    ) !u32 {
        if (from.look(item)) |turn| return turn;
        const data = from.list.items[item];
        const next = try dest.push(heap.bank, data);
        from.burn(item, next);
        return next;
    }
};

/// 32-bit handle to either terminal or operation; implicitly indexes
/// into some `Tree` aggregate.
pub const Node = packed struct {
    tag: Tag,
    data: u29 = 0,

    pub fn calm(this: Node, flap: u1) bool {
        return switch (this.look()) {
            .hcat, .cons, .fork => view(Oper, this).flip == flap,
            else => true,
        };
    }

    pub fn warp(
        word: Node,
        heap: *Heap,
    ) !Node {
        if (word.calm(heap.tick)) return word;

        const dest: *Rack(Pair) = word.rack(heap.new());
        const from: *Rack(Pair) = word.rack(heap.old());

        const next = try heap.copy(Pair, from, dest, word.unit());
        const new_node = word.onto(@intCast(next));

        return new_node;
    }

    pub fn onto(this: Node, item: u21) Node {
        var oper = view(Oper, this);
        oper.item = item;
        oper.flip ^= 1;
        return @bitCast(oper);
    }

    pub fn rack(this: Node, heap: *Half) *Rack(Pair) {
        return switch (this.tag) {
            .hcat => &heap.hcat,
            .fork => &heap.fork,
            .cons => &heap.cons,
            else => unreachable,
        };
    }

    pub fn unit(this: Node) u21 {
        return view(Oper, this).item;
    }

    pub const Form = Tag;

    pub const Look = union(Tag) {
        span: Span,
        quad: Quad,
        trip: Trip,
        rune: Rune,
        hcat: Oper,
        fork: Oper,
        cons: Oper,
    };

    pub const Edit = union(Tag) {
        span: *Span,
        quad: *Quad,
        trip: *Trip,
        rune: *Rune,
        hcat: *Oper,
        fork: *Oper,
        cons: *Oper,
    };

    pub const halt = Node.fromRune(0, 0);
    /// Reserved empty rune used only as the head of an internal memo wrapper.
    pub const memo_mark = Node.fromRune(0, 1);

    pub fn view(comptime T: type, this: Node) T {
        return @bitCast(this);
    }

    fn mut(comptime T: type, this: *Node) *T {
        return @ptrCast(@alignCast(this));
    }

    pub fn easy(this: Node) bool {
        return this.tag != .hcat and this.tag != .fork;
    }

    pub fn look(this: Node) Look {
        return switch (this.tag) {
            .span => .{ .span = view(Span, this) },
            .quad => .{ .quad = view(Quad, this) },
            .trip => .{ .trip = view(Trip, this) },
            .rune => .{ .rune = view(Rune, this) },
            .hcat => .{ .hcat = view(Oper, this) },
            .fork => .{ .fork = view(Oper, this) },
            .cons => .{ .cons = view(Oper, this) },
        };
    }

    pub fn load(this: Node, heap: *const Half) Pair {
        return switch (this.look()) {
            .hcat => |hcat| heap.hcat.items[hcat.item],
            .fork => |fork| heap.fork.items[fork.item],
            .cons => |cons| heap.cons.items[cons.item],
            else => unreachable,
        };
    }

    pub fn edit(this: *Node) Edit {
        return switch (this.tag) {
            .span => .{ .span = mut(Span, this) },
            .quad => .{ .quad = mut(Quad, this) },
            .trip => .{ .trip = mut(Trip, this) },
            .rune => .{ .rune = mut(Rune, this) },
            .hcat => .{ .hcat = mut(Oper, this) },
            .fork => .{ .fork = mut(Oper, this) },
            .cons => .{ .cons = mut(Oper, this) },
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

    pub fn fromOper(kind: Tag, frob: Frob, flip: u1, what: u21) Node {
        const oper: Oper = .{
            .kind = kind,
            .frob = frob,
            .flip = flip,
            .item = what,
        };
        return @bitCast(oper);
    }

    pub const nl: Node = Node.fromRune(1, '\n');
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
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    try expectEmitString(&tree, "ABCD", try tree.text("ABCD"));
    try expectEmitString(&tree, "ABC", try tree.text("ABC"));
    try expectEmitString(&tree, "AB", try tree.text("AB"));
    try expectEmitString(&tree, "A", try tree.text("A"));
    try expectEmitString(&tree, "", try tree.text(""));
}

test "show text" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    try expectEmitString(&tree, "Hello, world!", try tree.text("Hello, world!"));
}

test "text dedup" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const n1 = try tree.text("Hello, world!");
    const n2 = try tree.text("Hello, world!");

    try expectEqual(n1.repr(), n2.repr());
    try expectEqual(1 + "Hello, world!".len, tree.blob.items.len);

    const n3 = try tree.text("Hello");
    try expect(n2.repr() != n3.repr());
    try expectEqual(1 + "Hello, world!".len + 6, tree.blob.items.len);
}

test "emit plus node" {
    var tree = try Tree.init(std.testing.allocator);
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
    var t = try Tree.init(std.testing.allocator);
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
    var t = try Tree.init(std.testing.allocator);
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
    try expectEqual(0, t.heap.new().hcat.list.items.len);
    try expectEmitString(&t, "Hello, world!\n", fused);
}

test "fuse nl <> text" {
    var t = try Tree.init(std.testing.allocator);
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
    try expectEqual(0, t.heap.new().hcat.list.items.len);
    try expectEmitString(&t, "\nHello, world!", fused);
}

test "maze evaluation chooses best layout" {
    var tree = try Tree.init(std.testing.allocator);
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
    const result = try tree.pick(std.testing.allocator, cost, doc);

    const buf = try std.testing.allocator.alloc(u8, 64);
    defer std.testing.allocator.free(buf);
    var sink = std.Io.Writer.fixed(buf);
    try tree.emit(&sink, result.idea.node);
    try expectEqualStrings("foo bar", sink.buffered());
}

test "concatenation preserves shorter costlier frontier layout" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const cheap_long = try tree.text("12345");
    const costly_short = try tree.plus(Node.nl, try tree.text("x"));
    const tradeoff = try tree.fork(cheap_long, costly_short);
    const prefix_choice = try tree.plus(try tree.text("a"), tradeoff);
    const doc = try tree.plus(prefix_choice, try tree.text("ZZZZZZ"));

    const result = try tree.pick(std.testing.allocator, F1.init(6), doc);
    try expectEqual(1, result.idea.gist.rank.o);
    try expectEqual(1, result.idea.gist.rank.h);
    try expectEmitString(&tree, "a\nxZZZZZZ", result.idea.node);
}

test "nest context reaches a right-associated hcat tail" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const tail = try tree.cat(&.{
        Node.nl,
        try tree.text("12345"),
        Node.nl,
        try tree.text("b"),
    });
    const doc = try tree.nest(2, try tree.plus(try tree.text("a"), tail));
    const result = try tree.pick(std.testing.allocator, F1.init(6), doc);

    try expectEqual(1, result.idea.gist.rank.o);
    try expectEqual(2, result.idea.gist.rank.h);
    try expectEqual(3, result.idea.gist.last);
    try expectEmitString(&tree, "a\n  12345\n  b", result.idea.node);
}

test "nest modifier survives fork elimination" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const branch_a = try tree.cat(&.{ try tree.text("a"), Node.nl, try tree.text("b") });
    const branch_b = try tree.cat(&.{ try tree.text("c"), Node.nl, try tree.text("d") });
    const doc = try tree.nest(3, try tree.fork(branch_a, branch_b));
    const result = try tree.pick(std.testing.allocator, F1.init(6), doc);

    try expectEqual(4, result.idea.gist.last);
    try expectEmitString(&tree, "a\n   b", result.idea.node);
}

test "structural memo weight inserts a transparent checkpoint" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    var doc = try tree.text("a");
    for (0..5) |_| {
        doc = try tree.hcat(.{}, doc, try tree.text("a"));
        const pair = tree.heap.new().hcat.list.items[Node.view(Oper, doc).item];
        try expect(pair.head != Node.memo_mark);
    }
    doc = try tree.hcat(.{}, doc, try tree.text("a"));

    const wrapper = tree.heap.new().hcat.list.items[Node.view(Oper, doc).item];
    try expectEqual(Node.memo_mark, wrapper.head);
    try expectEqual(0, tree.memoWeight(doc));
    try expectEmitString(&tree, "aaaaaaa", doc);
}

test "shared memo checkpoint is reused" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    var shared = try tree.text("a");
    for (0..6) |_| shared = try tree.hcat(.{}, shared, try tree.text("a"));
    const doc = try tree.fork(shared, shared);
    var stat: Stat = .{};
    const result = try tree.pickWithStatistics(std.testing.allocator, F1.init(80), doc, .{}, &stat);

    try expectEqual(1, stat.memo_hits);
    try expectEqual(1, stat.memo_entries);
    try expectEmitString(&tree, "aaaaaaa", result.idea.node);
}

test "collector forwarding does not depend on cell fields" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    var doc = try tree.text("a");
    for (0..300) |_| doc = try tree.hcat(.{}, doc, try tree.text("a"));

    var stat: Stat = .{};
    const result = try tree.pickWithStatistics(
        std.testing.allocator,
        F1.init(400),
        doc,
        .{ .gc_tide = 1 },
        &stat,
    );
    try expect(stat.gc_count > 0);

    var storage: [301]u8 = undefined;
    var sink = std.Io.Writer.fixed(&storage);
    try tree.emit(&sink, result.idea.node);
    try expectEqual(301, sink.buffered().len);
    for (sink.buffered()) |char| try expectEqual('a', char);
}

test "flatten preserves memo checkpoints" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    var doc = try tree.text("a");
    for (0..5) |_| doc = try tree.hcat(.{}, doc, try tree.text("a"));
    doc = try tree.hcat(.{}, doc, Node.nl);
    const flattened = try tree.flat(doc);

    const wrapper = tree.heap.new().hcat.list.items[Node.view(Oper, flattened).item];
    try expectEqual(Node.memo_mark, wrapper.head);
    try expectEmitString(&tree, "aaaaaa ", flattened);
}

test "computation width delays and forces unavoidable overflow" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const doc = try tree.text("abcdefgh");
    var stat: Stat = .{};
    const result = try tree.pickWithStatistics(
        std.testing.allocator,
        F1.init(4),
        doc,
        .{ .computation_width = 4 },
        &stat,
    );

    try expectEqual(4, result.idea.gist.rank.o);
    try expectEqual(1, stat.cope_deferred);
    try expectEqual(1, stat.cope_forced);
    try expectEmitString(&tree, "abcdefgh", result.idea.node);
}

test "concatenation propagates a delayed tail" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const doc = try tree.plus(try tree.text("abc"), try tree.text("def"));
    var stat: Stat = .{};
    const result = try tree.pickWithStatistics(
        std.testing.allocator,
        F1.init(4),
        doc,
        .{ .computation_width = 4 },
        &stat,
    );

    try expectEqual(2, result.idea.gist.rank.o);
    try expect(stat.cope_deferred >= 2);
    try expectEqual(1, stat.cope_forced);
    try expectEmitString(&tree, "abcdef", result.idea.node);
}

test "a bounded choice wins over a delayed choice" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const doc = try tree.fork(try tree.text("abcdefgh"), try tree.text("ok"));
    var stat: Stat = .{};
    const result = try tree.pickWithStatistics(
        std.testing.allocator,
        F1.init(4),
        doc,
        .{ .computation_width = 4 },
        &stat,
    );

    try expectEqual(0, result.idea.gist.rank.o);
    try expect(stat.cope_deferred >= 1);
    try expectEqual(0, stat.cope_forced);
    try expectEmitString(&tree, "ok", result.idea.node);
}

test "forced computation becomes bounded again after newline" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const suffix = try tree.fork(try tree.text("abcdefgh"), try tree.text("ok"));
    const doc = try tree.cat(&.{ try tree.text("abcdefgh"), Node.nl, suffix });
    var stat: Stat = .{};
    const result = try tree.pickWithStatistics(
        std.testing.allocator,
        F1.init(4),
        doc,
        .{ .computation_width = 4 },
        &stat,
    );

    try expect(stat.cope_forced >= 1);
    try expectEmitString(&tree, "abcdefgh\nok", result.idea.node);
}

test "forcing a computation selects one recovered measure" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    const short_costly = try tree.plus(Node.nl, try tree.text("x"));
    const suffix = try tree.fork(try tree.text("1234"), short_costly);
    const doc = try tree.cat(&.{ try tree.text("abcdefgh"), Node.nl, suffix });
    var stat: Stat = .{};
    _ = try tree.pickWithStatistics(
        std.testing.allocator,
        F1.init(4),
        doc,
        .{ .computation_width = 4 },
        &stat,
    );

    try expect(stat.cope_forced >= 1);
    try expectEqual(1, stat.size);
}

test "flatten fused text <> nl" {
    var t = try Tree.init(std.testing.allocator);
    defer t.deinit();

    const fused = try t.plus(try t.text("A"), .nl);
    try expectEmitString(&t, "A ", try t.flat(fused));
}

test "nest braces emit" {
    var t = try Tree.init(std.testing.allocator);
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
    var t = try Tree.init(std.testing.allocator);
    defer t.deinit();

    const cost = F1.init(32);
    const rank = try t.rank(
        cost,
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

    try expectEqual(2, rank.h);
    try expectEqual(0, rank.o);
}

test "F2 cost matches example" {
    var t = try Tree.init(std.testing.allocator);
    defer t.deinit();

    // See Example 3.5. and Figure 7 in *A Pretty Expressive Printer*.

    const d1 = try t.text("   = func( pretty, print )");
    const cost = F2.init(6);
    const rank1 = try t.rank(cost, d1);

    try expectEqual(0, rank1.h);
    try expectEqual(20 * 20, rank1.o);

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

    const rank2 = try t.rank(cost, d2);

    try expectEqual(3, rank2.h);
    try expectEqual(4 * 4 + 3 * 3 + 1, rank2.o);
}

test "flatten('a' <> nl <> 'b')" {
    var t = try Tree.init(std.testing.allocator);
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
    var t = try Tree.init(std.testing.allocator);
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
    var t = try Tree.init(std.testing.allocator);
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
