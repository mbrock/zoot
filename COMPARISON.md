# Pretty Expressive: OCaml vs Zig Implementation Comparison

## Overview

Both implementations are based on the paper "A Pretty Expressive Printer" (OOPSLA'23). The OCaml version (`pretty_expressive`) is by the paper's author Sorawee Porncharoenwase. Your Zig implementation in `src/pretty.zig` follows the same algorithm.

## Terminology Mapping

### OCaml → Zig

| OCaml Concept | Zig Equivalent | Notes |
|--------------|----------------|-------|
| `doc` | `Node` | Core document/layout type |
| `text "foo"` | `tree.text("foo")` | Create text node |
| `^^` (concat) | `tree.plus()` or `tree.hcat()` | Concatenation |
| `<|>` (choice) | `tree.fork()` | Choice between layouts |
| `<$>` (hard newline) | `try tree.plus(a, Node.nl)` followed by `tree.plus(_, b)` | Hard line break |
| `nl` | `Node.nl` | Newline that can flatten to space |
| `nest n doc` | `tree.nest(n, doc)` | Add indentation |
| `align doc` | `tree.warp(doc)` | Align to current column |
| `flatten doc` | `tree.flat(doc)` | Convert newlines to spaces |
| `group doc` | `tree.fork(doc, try tree.flat(doc))` | Try flat, else original |
| `pretty_format` | `tree.pick()` then `tree.emit()` | Evaluate & render |
| Cost Factory | `Cost` enum (`.f1` or `.f2`) | Cost function selection |
| Page width | Part of `Cost` value | Layout width limit |

## Key Architectural Differences

### 1. **Language Paradigms**
- **OCaml**: Functional, immutable by default, uses functors for abstraction
- **Zig**: Systems language, explicit memory management, comptime generics

### 2. **Node Representation**

**OCaml**: Abstract type in the functor, hidden behind interface
```ocaml
type doc  (* opaque *)
```

**Zig**: Packed 32-bit representation with tags
```zig
pub const Node = packed struct {
    tag: Tag,      // 3 bits
    data: u29 = 0, // 29 bits
}
```

Your Zig implementation uses several clever optimizations:
- **Inline text**: Strings ≤4 ASCII chars stored directly in `Node` (as `Quad`)
- **Inline runes**: Single repeated character stored inline (`Rune`)
- **Trips**: Small UTF-8 sequences with repeat count
- **Spans**: Larger text stored in `tree.blob` with index
- **Dense encoding**: All in 32 bits!

### 3. **Memory Management**

**OCaml**: Automatic garbage collection
```ocaml
let doc = text "foo" ^^ text "bar"  (* GC handles cleanup *)
```

**Zig**: Explicit arena allocation with semi-space GC
```zig
pub const Heap = struct {
    heap: [2]Half,  // Two semispaces for copying GC
    tick: u1 = 0,   // Current space
    // ...
}
```

Your implementation uses a **copying garbage collector** during layout evaluation:
- Two semispaces (`heap[0]` and `heap[1]`)
- `flip()` switches active space
- `warp()` copies reachable nodes to new space
- Collects unreachable layouts during search

### 4. **Cost Functions**

**OCaml**: Uses default factory with three components
```ocaml
(* Badness, column overflow, height *)
val default_cost_factory : page_width:int -> ...
```

**Zig**: Two explicit cost functions from the paper
```zig
pub const F1 = struct {  // Linear overflow
    pub fn init(w: u16) Cost { return .{ .f1 = w }; }
};

pub const F2 = struct {  // Squared overflow (default in OCaml)
    pub fn init(w: u16) Cost { return .{ .f2 = w }; }
};

pub const Rank = packed struct {
    o: u32 = 0,  // overflow cost
    h: u32 = 0,  // height (newlines)
};
```

### 5. **Evaluation Strategy**

Both use the same **CEK machine** (Control/Environment/Continuation) but with different styles:

**OCaml**: Hidden in the functor implementation

**Zig**: Explicit in `Loop.step()`
```zig
pub const Exec = struct {
    node: Node,
    tick: union(enum) {
        eval: Crux,  // Evaluating a node
        give: Gist,  // Returning a result
    },
    then: Kont = Kont.none,  // Continuation
};
```

Your implementation uses two phases:
1. **icky loop**: Find any valid layout (even bad ones)
2. **good loop**: Find optimal layouts (no overflow allowed)

### 6. **Memoization**

Both implementations memoize subproblem results:

**OCaml**: Internal hash table

**Zig**: Explicit `Memo` type
```zig
pub const Memo = std.AutoHashMap(Item, Idea);

pub const Item = packed struct {
    node: Node,
    head: u16,  // Current column
    base: u16,  // Indent base
};
```

## Example Code Comparison

### Creating a simple document

**OCaml**:
```ocaml
module P = Pretty_expressive.Printer.Make(
  val Pretty_expressive.Printer.default_cost_factory ~page_width:80 ()
)
open P

let doc = text "foo" ^^ space ^^ text "bar"
let output = pretty_format doc
```

**Zig**:
```zig
var tree = Tree.init(allocator);
defer tree.deinit();

const doc = try tree.plus(
    try tree.plus(try tree.text("foo"), try tree.text(" ")),
    try tree.text("bar")
);

const cost = F2.init(80);
const result = try tree.pick(allocator, cost, doc);

var writer = std.io.getStdOut().writer();
try tree.emit(&writer, result.idea.node);
```

### Choice between layouts

**OCaml**:
```ocaml
let inline = text "foo" ^^ space ^^ text "bar" in
let multiline = text "foo" <$> text "bar" in
let doc = inline <|> multiline
```

**Zig**:
```zig
const inline = try tree.plus(
    try tree.plus(try tree.text("foo"), try tree.text(" ")),
    try tree.text("bar")
);
const multiline = try tree.plus(
    try tree.plus(try tree.text("foo"), Node.nl),
    try tree.text("bar")
);
const doc = try tree.fork(inline, multiline);
```

### Alignment

**OCaml**:
```ocaml
let doc = text "AAA" ^^ align (text "X" <$> text "Y")
(* Output:
   AAAX
      Y
*)
```

**Zig**:
```zig
const doc = try tree.plus(
    try tree.text("AAA"),
    try tree.warp(
        try tree.plus(
            try tree.plus(try tree.text("X"), Node.nl),
            try tree.text("Y")
        )
    )
);
```

## Performance Characteristics

### OCaml Version
- Functional/immutable: easier reasoning, more GC pressure
- Abstracts cost function via functor: flexible but some indirection
- Generally optimized by author for typical use cases

### Zig Version
- Explicit memory control: predictable performance
- Copying GC during evaluation: bounded memory, cache-friendly
- 32-bit node encoding: excellent memory density
- Inline small strings: avoids indirection for common case
- Memoization with explicit hash map: tunable

Your tests show GC in action:
```zig
// From src/pretty.zig:46
log.info("gc: heap {Bi:>6.2} to {Bi:>6.2}", .{ size0, size1 });
```

## Notable Features in Your Implementation

1. **Hash-consing**: Deduplicates `cons` nodes
   ```zig
   pub fn hashcons(tree: *Tree, frob: Frob, head: Node, tail: Node) !Node
   ```

2. **Text deduplication**: Reuses string pool entries
   ```zig
   // In tree.text(): searches blob for existing string
   const spot = if (std.mem.indexOf(u8, tree.blob.items, spanz)) |i| i else ...
   ```

3. **Trigger-based GC**: Collects when heap exceeds threshold
   ```zig
   fn fuss(this: *@This()) !void {
       if (this.heap.size() < this.tide) return;
       try this.tidy();
       this.tide = @max(this.tide, size1 + size1 * 2);  // Grow threshold
   }
   ```

4. **Statistics tracking**:
   ```zig
   pub const Stat = struct {
       peak: usize = 0,
       completions: usize = 0,
       memo_hits: usize = 0,
       memo_misses: usize = 0,
       memo_entries: usize = 0,
       size: usize = 0,
   };
   ```

## Interesting Observations

1. **Your Zig impl is more explicit** about memory and control flow, which is great for learning the algorithm internals

2. **OCaml version has more combinators** (`vcat`, `hcat`, `fold_doc`, etc.) - you might want to add these helpers

3. **Cost functions**: You implement F1 and F2 from the paper; OCaml uses a more complex default with three components

4. **Both handle "icky" (bad) layouts** during search - your two-phase approach (`ickyloop` / `goodloop`) is interesting!

## Next Steps for Exploration

1. **Try different cost functions**: Compare F1 vs F2 on the same documents
2. **Benchmark**: Your Zig version might be faster due to dense encoding
3. **Add helpers**: Port some OCaml combinators like `vcat`, `hcat`, `parens`, etc.
4. **Tune GC**: Experiment with `tide` threshold
5. **Visualize**: Use your stats to understand layout search space

## Resources

- **OCaml docs**: https://sorawee.github.io/pretty-expressive-ocaml/
- **Paper**: "A Pretty Expressive Printer" (OOPSLA'23)
- **Your tests**: See `src/pretty.zig` lines 1751-2043 for excellent test examples!

---

Both implementations are faithful to the paper and production-ready. The OCaml version provides a clean API with hidden complexity, while your Zig version exposes the algorithmic details beautifully. Great work!
