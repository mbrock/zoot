use std::convert::Infallible;

use crate::document::{Document, Node};
use crate::evaluator::Candidate;

const SPACES: &str = "                                                                ";

/// Output callbacks used while rendering a selected layout.
///
/// Span callbacks are no-ops by default, so sinks interested only in text
/// need to implement [`RenderSink::write_str`].
pub trait RenderSink<A> {
    /// The sink's output error.
    type Error;

    /// Write literal output.
    ///
    /// # Errors
    ///
    /// Returns any error reported by the underlying output destination.
    fn write_str(&mut self, text: &str) -> Result<(), Self::Error>;

    /// Begin an annotated span.
    ///
    /// # Errors
    ///
    /// Returns any error reported by the underlying output destination.
    fn begin_span(&mut self, _metadata: &A) -> Result<(), Self::Error> {
        Ok(())
    }

    /// End an annotated span.
    ///
    /// # Errors
    ///
    /// Returns any error reported by the underlying output destination.
    fn end_span(&mut self, _metadata: &A) -> Result<(), Self::Error> {
        Ok(())
    }
}

/// Render a selected candidate through a custom sink.
///
/// # Errors
///
/// Returns the first error reported by the sink.
pub fn render_with<A, S>(candidate: &Candidate<A>, sink: &mut S) -> Result<(), S::Error>
where
    S: RenderSink<A>,
{
    render_layout(candidate.layout(), sink, 0, 0).map(|_| ())
}

/// Render a selected candidate to a string, ignoring span annotations.
#[must_use]
pub fn render<A>(candidate: &Candidate<A>) -> String {
    let mut sink = StringSink(String::new());
    match render_with(candidate, &mut sink) {
        Ok(()) => sink.0,
        Err(error) => match error {},
    }
}

struct StringSink(String);

impl<A> RenderSink<A> for StringSink {
    type Error = Infallible;

    fn write_str(&mut self, text: &str) -> Result<(), Self::Error> {
        self.0.push_str(text);
        Ok(())
    }
}

fn render_layout<A, S>(
    document: &Document<A>,
    sink: &mut S,
    last: usize,
    base: usize,
) -> Result<usize, S::Error>
where
    S: RenderSink<A>,
{
    match document.node() {
        Node::Text(text) => {
            sink.write_str(text)?;
            Ok(last.saturating_add(text.len()))
        }
        Node::Verbatim(text) => {
            sink.write_str(text)?;
            Ok(text.rfind('\n').map_or_else(
                || last.saturating_add(text.len()),
                |index| text.len() - index - 1,
            ))
        }
        Node::Newline => {
            sink.write_str("\n")?;
            write_indentation(sink, base)?;
            Ok(base)
        }
        Node::Concat(left, right) => {
            let last = render_layout(left, sink, last, base)?;
            render_layout(right, sink, last, base)
        }
        Node::Nest(amount, child) => render_layout(child, sink, last, base.saturating_add(*amount)),
        Node::Align(child) => render_layout(child, sink, last, last),
        Node::Span(metadata, child) => {
            sink.begin_span(metadata)?;
            let last = render_layout(child, sink, last, base)?;
            sink.end_span(metadata)?;
            Ok(last)
        }
        Node::Memo(child) => render_layout(child, sink, last, base),
        Node::Choice(_, _) => {
            unreachable!("a selected candidate cannot contain an unresolved choice")
        }
    }
}

fn write_indentation<A, S>(sink: &mut S, mut amount: usize) -> Result<(), S::Error>
where
    S: RenderSink<A>,
{
    while amount >= SPACES.len() {
        sink.write_str(SPACES)?;
        amount -= SPACES.len();
    }
    sink.write_str(&SPACES[..amount])
}
