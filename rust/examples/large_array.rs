//! Exercise construction, planning, rendering, and destruction of a large
//! JSON-like array document on a fixed-size worker stack.

use std::env;
use std::thread;

use zoot::{pick, render, Cost, Doc};

fn array_document(element_count: usize) -> Doc {
    let elements: Vec<_> = (0..element_count)
        .map(|value| Doc::text(value.to_string()))
        .collect();

    let horizontal = Doc::text("[")
        .append(Doc::separated_by(
            &Doc::text(", "),
            elements.iter().cloned(),
        ))
        .append(Doc::text("]"));

    let vertical_separator = Doc::text(",").append(Doc::newline());
    let vertical_body = Doc::separated_by(&vertical_separator, elements);
    let vertical = Doc::text("[")
        .append(Doc::nest(2, Doc::newline().append(vertical_body)))
        .append(Doc::newline())
        .append(Doc::text("]"));

    Doc::choice(horizontal, vertical)
}

fn run(element_count: usize) {
    let document = array_document(element_count);
    eprintln!("built");

    let plan = pick(&document, &Cost::f1(80));
    eprintln!(
        "planned: frontier={} rank=({},{},{})",
        plan.frontier().len(),
        plan.candidate().rank().overflow(),
        plan.candidate().rank().indentation(),
        plan.candidate().rank().height(),
    );

    let output = render(plan.candidate());
    eprintln!("rendered: {} bytes", output.len());

    drop(output);
    drop(plan);
    drop(document);
    eprintln!("dropped");
}

fn main() {
    let mut arguments = env::args().skip(1);
    let element_count = arguments.next().map_or(10_000, |value| {
        value.parse().expect("invalid element count")
    });
    let stack_mib = arguments
        .next()
        .map_or(8, |value| value.parse().expect("invalid stack size"));
    assert!(arguments.next().is_none(), "too many arguments");

    eprintln!(
        "large JSON array: elements={element_count} stack={stack_mib} MiB optimized={}",
        !cfg!(debug_assertions),
    );
    thread::Builder::new()
        .name("zoot-large-array".into())
        .stack_size(stack_mib * 1024 * 1024)
        .spawn(move || run(element_count))
        .expect("could not start experiment thread")
        .join()
        .expect("experiment thread panicked");
}
