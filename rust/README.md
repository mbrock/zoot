# Rust Zoot

This crate is a direct Rust implementation of Zoot's Pareto-optimal document
evaluator. It provides:

- arbitrary document choices, concatenation, nesting, alignment, grouping,
  verbatim blocks, and cost-transparent annotated spans;
- unrestricted Pareto frontiers ordered by final column and lexicographic
  `(overflow, indentation, height)` cost;
- linear-overflow F1, squared-overflow F2, and custom text cost functions;
- structural memo checkpoints for shared document DAGs;
- the paper's bounded computation-width taint and forced recovery behavior;
- plain string rendering and an annotation-aware rendering trait.

Use `Doc` for ordinary documents. `Document<A>` carries custom span metadata
of type `A` when annotation-aware rendering is needed.

The implementation is dependency-free. From the repository root, run:

```sh
make rust-test
```

The crate can also be tested directly:

```sh
cargo test --manifest-path rust/Cargo.toml
```

The `large_array` example builds, plans, renders, and drops a JSON-like array
document on a fixed-size worker stack. Its arguments are element count and
stack size in MiB. The following intentionally reproduces a planning-time
stack overflow on the current recursive evaluator; 7,000 elements completes
on the same stack in the tested Nix release build:

```sh
cargo run --release --manifest-path rust/Cargo.toml \
  --example large_array -- 10000 8
```

The crate-level documentation contains a complete construction, selection, and
rendering example.
