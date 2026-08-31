//! Format a Rust source file with Zoot.

use std::env;
use std::fs;

use zoot::source::{format_source, format_source_ansi};

fn main() {
    let mut arguments = env::args().skip(1).collect::<Vec<_>>();
    let ansi = arguments.iter().any(|argument| argument == "--ansi");
    arguments.retain(|argument| argument != "--ansi");
    let path = arguments
        .first()
        .expect("usage: format_source PATH [WIDTH] [--ansi]");
    let width = arguments
        .get(1)
        .map_or(Ok(80), |width| width.parse())
        .expect("WIDTH must be an unsigned integer");
    assert!(
        arguments.len() <= 2,
        "usage: format_source PATH [WIDTH] [--ansi]"
    );

    let source = fs::read_to_string(path).expect("failed to read source file");
    let output = if ansi {
        format_source_ansi(&source, width)
    } else {
        format_source(&source, width)
    };
    print!("{output}");
}
