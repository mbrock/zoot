# Pareto Frontier Refactor - Implementation Notes

## Problem Identified

The Zig pretty printer has **exponential performance** vs OCaml's linear scaling:
- **N=22 choices**: Zig 320ms (12.5M memo lookups) vs OCaml 54µs
- **Root cause**: Fork nodes are never memoized, so same subproblems explored 2^N times
- **Missing**: OCaml stores `measure_set` (pareto frontier) per memo entry; Zig stores single `Idea`

## Solution Architecture

### Deck/Duel System (✅ DONE)

**Deck** - Packed 32-bit handle to pareto frontier:
```zig
pub const Deck = packed struct {
    flip: u1,    // GC semispace bit
    item: u31,   // Index into duel rack
};
```

**Duel** - Linked list cell in pareto frontier:
```zig
pub const Duel = struct {
    node: Node,  // Resolved (forkless) layout node (32b)
    gist: Gist,  // Layout metrics: last, rows, rank (3x32b)
    next: Deck,  // Next duel in list (32b)
};
// Total: 5 x u32 = nice for Hack forwarding pointer
```

**Frontier operations** (all implemented in `Loop`):
- `singleton(node, gist) -> Deck` - create one-element frontier
- `dominated(deck, gist) -> bool` - check if gist dominated by any in deck
- `cons_to_deck(deck, node, gist) -> Deck` - add to frontier, filter dominated
- `merge_decks(a, b) -> Deck` - merge frontiers, keep pareto-optimal

**GC integration**: `Half.duel: Rack(Duel)` - Cheney's algorithm compacts linked lists!

## What's Left (TODO)

### 1. Change Exec and Memo to use Decks

**Current**:
```zig
pub const Exec = struct {
    tick: union(enum) {
        eval: Crux,
        give: Gist,  // ❌ Single result
    },
    ...
};
pub const Memo = std.AutoHashMap(Item, Idea);  // ❌ Single idea per node
```

**Target**:
```zig
pub const Exec = struct {
    tick: union(enum) {
        eval: Crux,
        give: Deck,  // ✅ Frontier of results
    },
    ...
};
pub const Memo = std.AutoHashMap(Item, Deck);  // ✅ Frontier per node
```

### 2. Update terminal nodes (rune/quad/span/trip)

**Pattern** - in `step()` around line 268:
```zig
.rune => |rune| {
    const gist = rune.toGist(crux, this.cost);
    exec.tick = .{ .give = try this.singleton(exec.node, gist) };
    return;
},
```

Do same for `.quad`, `.span`, `.trip` (all around lines 268-280).

### 3. Update hcat continuation - Cartesian product

**Current** (line ~390):
```zig
.tail => |cont| {
    // Combines head.gist + tail.gist into one gist
    gist = ...;
    node = try this.tree.cons(...);
    try this.memo.put(cont.item, .{ .node = node, .gist = gist });
```

**Target**:
```zig
.tail => |cont| {
    // Cartesian product: for each head_idea × each tail_idea
    const head_deck = cont.head_deck;  // Need to store this in Ktx2
    const tail_deck = exec.tick.give;

    var result = Deck.none;
    var head_curr = head_deck;
    while (head_curr.item != 0x7FFFFFFF) {
        const head_duel = this.heap.new().duel.list.items[head_curr.item];
        var tail_curr = tail_deck;
        while (tail_curr.item != 0x7FFFFFFF) {
            const tail_duel = this.heap.new().duel.list.items[tail_curr.item];

            // Combine
            var gist = tail_duel.gist;
            gist.rows +|= head_duel.gist.rows;
            gist.rank = this.cost.plus(tail_duel.gist.rank, head_duel.gist.rank);

            const node = try this.tree.cons(oper.frob, head_duel.node, tail_duel.node);

            // Add to result frontier
            result = try this.cons_to_deck(result, node, gist);

            tail_curr = tail_duel.next;
        }
        head_curr = head_duel.next;
    }

    try this.memo.put(cont.item, result);
    exec.tick = .{ .give = result };
```

**Note**: Need to change `Ktx2` to store `head_deck: Deck` instead of individual gist/node.

### 4. Update fork - Merge frontiers

**Current** (line ~310):
```zig
.fork => |fork| {
    // Just enqueue right branch, continue with left
    exec.node = pair.head;
    var task = exec.*;
    task.node = pair.tail;
    try this.pile.append(this.tree.bank, task);
    return;
}
```

**Problem**: No way to know when both branches done!

**Solution**: Don't split forks in `step()`. Instead, in the main loops, when we complete a fork evaluation, check if we've seen it before in the memo. If yes, reuse. If no, continue evaluating and memoize the complete frontier at the end.

**Alternative simpler approach**: Keep BFS fork splitting, but memoize immediately with partial results, then later merge when we see the same fork again. OCaml might do this with lazy thunks.

**Look at OCaml** `printer.ml` around line 392 for `resolve` and line 469 for `cache` to understand their fork handling.

## Key Patterns

**GC participation**: Any new heap type needs:
1. Add `Rack(T)` field to `Half`
2. Implement `drag(self: *T, heap: *Heap)` to move child nodes
3. Update `Half.{deinit, calm, size, pull}` to include new rack

**Pareto filtering**: Use `wins(cost, a, b)` - returns true if `a` dominates `b`.

**BFS**: The `pile` queue processes fork branches depth-first within breadth-first traversal.

## Testing Strategy

Run `zig build trace -Doptimize=Debug` with 3 forks - should see:
- Frontiers with multiple ideas at choice points
- Memo hits reusing complete frontiers
- Far fewer total evaluations (should be ~O(N) not O(2^N))

Compare with `eval $(opam env) && dune exec ./bench_explore.exe` to verify similar scaling.

## Current Status

✅ **COMPLETE - REFACTOR SUCCESSFUL!**

All tasks completed:
- ✅ Deck/Duel infrastructure complete
- ✅ Frontier manipulation functions complete
- ✅ GC integration working
- ✅ Exec.tick.give and Memo changed to use Deck
- ✅ Terminal nodes updated to use singleton()
- ✅ Hcat Cartesian product implemented
- ✅ Fork merging with pareto frontiers
- ✅ Tests passing
- ✅ **MASSIVE PERFORMANCE WIN!**

## Results

**Before refactor:**
- N=22 choices: 320ms (12.5M memo lookups) - O(2^N) exponential

**After refactor:**
- N=22 choices: **~120µs** (88 memo lookups) - O(N) linear
- All tests pass ✅
- Pretty multiline output works correctly ✅

**Speedup: ~2666x faster!** 🚀

## Key Implementation Details

### Two Comparison Functions
The implementation uses **both** comparison strategies:

1. **Lexicographic** (`Cost.wins`): Used in the "running best" scan during Cartesian product
   - Compares ranks as `(overflow, height)` tuples
   - Returns true if `a < b` lexicographically

2. **Pareto Dominance** (`Loop.wins`): Used in frontier filtering
   - Checks if `a` dominates `b` on **all three dimensions**: `last`, `overflow`, `height`
   - Returns true if all are `≤` with at least one `<`
   - This matches OCaml's `<==` operator which checks both `last` and `cost`

### Cartesian Product Logic
For each head idea, we do a "running best" scan through tail ideas:
- Start with head+first_tail as current_best
- For each subsequent tail, combine with head
- If new cost ≤ current_best (lexicographically), update current_best
- Otherwise, emit current_best to partial frontier and make new one current_best
- At end, emit final current_best
- Merge all partial frontiers with global result

This reduces N×M combinations to typically O(N) or O(M) results.

---

*Written during session investigating exponential blowup in choices benchmark*
*Completed in follow-up session with successful refactor*
*Final debugging: Fixed pareto dominance to include `last` dimension*
