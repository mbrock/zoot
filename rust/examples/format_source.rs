//! Format a Rust source file with Zoot.

use std::env;
use std::fs;

use zoot::source::format_source;

fn main() {
    let mut arguments = env::args().skip(1);
    let path = arguments.next().expect("usage: format_source PATH [WIDTH]");
    let width = arguments
        .next()
        .map_or(Ok(80), |width| width.parse())
        .expect("WIDTH must be an unsigned integer");
    assert!(
        arguments.next().is_none(),
        "usage: format_source PATH [WIDTH]"
    );

    let source = fs::read_to_string(path).expect("failed to read source file");
    print!("{}", format_source(&source, width));
}
