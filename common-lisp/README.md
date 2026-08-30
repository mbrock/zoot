# Common Lisp Zoot

This directory contains a direct recursive implementation of Zoot's document
evaluator. It follows the arbitrary-choice and concatenation semantics from
*A Pretty Expressive Printer* and the rank and context rules in
`src/recursive.zig`.

The implementation is intentionally a reference animal rather than a port of
Zig's compact representation:

- each document kind has its own structure type, sharing memo state through a
  base structure; evaluator and renderer semantics use generic dispatch;
- Pareto frontiers remain unrestricted, but the common cardinalities avoid
  adjustable vectors: singleton frontiers are bare candidates and two-point
  frontiers are immutable `duel` structures; vectors represent empty and
  larger frontiers;
- tainted promises are explicit small continuation-context structures rather
  than closures;
- dominance compares final column and lexicographic `(overflow, height)` cost;
- both linear-overflow F1 and squared-overflow F2 costs are available;
- text cost is an actual function value and may be dynamically overridden by
  binding `*cost-measure*` around `pick`;
- per-pick cost and statistics are dynamically scoped, so recursive evaluator
  methods carry only the document context they transform;
- documents are single-use search spaces; each memo checkpoint lazily owns an
  `EQL` context table keyed by a packed current-column/indentation integer, and
  the whole search graph is reclaimed together after planning;
- the OCaml six-level structural weight policy enables those tables only at
  periodic memo checkpoints, without adding Zig-style wrapper nodes;
- evaluation uses the paper's computation-width taint: work outside the bounded
  region becomes a deferred context for one candidate, ordinary choices beat
  tainted branches, and unavoidable taint is forced at the root;
- ordinary Pareto evaluation remains exact and frontiers remain unrestricted.

Run the tests with:

```sh
make lisp-test
```

Run the small benchmark suite with:

```sh
make lisp-benchmark RUNS=20
```

Profile fresh ternary documents with SBCL's statistical profiler:

```sh
make lisp-profile LISP_PROFILE_SAMPLES=1500 LISP_PROFILE_DEPTH=4
```

Statistics collection is selected when the system is compiled with the
`:zoot-statistics` feature. Tests and benchmarks enable it; ordinary builds and
profiling omit all counter updates and frontier-note dispatch by default. Enable
it for a profile when studying the counters themselves:

```sh
make lisp-profile LISP_PROFILE_STATISTICS=1
```

Each iteration constructs and plans a fresh document. The suite reports mean
build, plan, and end-to-end times along with output size, selected rank, root
and maximum frontier sizes, evaluator/memo counts, taint activity, and a
frontier-size histogram. Its workloads cover token-preserving ternary Lisp
layout, a shared document DAG, and repeatedly forced computation-width taint.

The tests include a deliberately arbitrary choice with a three-point Pareto
frontier. It demonstrates that this version has no analogue of Zig's current
two-Duel assertion.
