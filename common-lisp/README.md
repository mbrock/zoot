# Common Lisp Zoot

This directory contains a direct recursive implementation of Zoot's document
evaluator. It follows the arbitrary-choice and concatenation semantics from
*A Pretty Expressive Printer* and the rank and context rules in
`src/recursive.zig`.

The implementation is intentionally a reference animal rather than a port of
Zig's compact representation:

- documents and resolved layouts are immutable structures;
- Pareto frontiers are unrestricted adjustable vectors;
- dominance compares final column and lexicographic `(overflow, height)` cost;
- both linear-overflow F1 and squared-overflow F2 costs are available;
- recursive evaluation is memoized by document identity, current column, and
  indentation base;
- evaluation uses the paper's computation-width taint: work outside the bounded
  region becomes a thunk for one candidate, ordinary choice branches beat
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

It reports total and mean planning time along with output size, selected rank,
root and maximum frontier sizes, evaluator/memo counts, taint activity, and a
frontier-size histogram. Its workloads cover token-preserving ternary Lisp
layout, a shared document DAG, and repeatedly forced computation-width taint.

The tests include a deliberately arbitrary choice with a three-point Pareto
frontier. It demonstrates that this version has no analogue of Zig's current
two-Duel assertion.
