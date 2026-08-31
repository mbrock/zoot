//! A direct, unrestricted implementation of the Pareto-optimal document
//! evaluator from *A Pretty Expressive Printer*.
//!
//! Documents describe arbitrary layout choices. [`pick`] evaluates those
//! choices to a Pareto frontier over final column and lexicographic
//! `(overflow, indentation, height)` cost; [`render`] emits the best candidate.
//!
//! ```
//! use zoot::{pick, render, Cost, Doc};
//!
//! let body = Doc::one_per_line([
//!     Doc::text("alpha"),
//!     Doc::text("beta"),
//! ]);
//! let document = Doc::in_parentheses(Doc::align(body.group()));
//!
//! assert_eq!(render(pick(&document, &Cost::f1(20)).candidate()), "(alpha beta)");
//! assert_eq!(render(pick(&document, &Cost::f1(7)).candidate()), "(alpha\n beta)");
//! ```

mod cost;
mod document;
mod evaluator;
mod render;
#[cfg(feature = "rust-format")]
pub mod source;

pub use cost::{linear_overflow_cost, squared_overflow_cost, Cost, Rank};
pub use document::Document;
pub use evaluator::{pick, pick_with_options, Candidate, PickOptions, Plan, Statistics};
pub use render::{render, render_with, RenderSink};

/// An unannotated document, convenient for ordinary text rendering.
pub type Doc = Document<()>;

/// Resolve and render a document in one call.
#[must_use]
pub fn format_document<A>(document: &Document<A>, cost: &Cost) -> String {
    render(pick(document, cost).candidate())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn descriptive_combinators_choose_for_width() {
        fn document() -> Doc {
            let body = Doc::one_per_line([Doc::text("alpha"), Doc::text("beta")]);
            Doc::in_parentheses(Doc::align(body.group()))
        }

        assert_eq!(format_document(&document(), &Cost::f1(20)), "(alpha beta)");
        assert_eq!(format_document(&document(), &Cost::f1(7)), "(alpha\n beta)");
    }

    #[test]
    fn arbitrary_choice_selects_the_best_layout() {
        let inline = Doc::cat([Doc::text("foo"), Doc::text(" "), Doc::text("bar")]);
        let multiline = Doc::cat([Doc::text("foo"), Doc::newline(), Doc::text("bar")]);
        let plan = pick(&Doc::choice(inline, multiline), &Cost::f1(10));

        assert_eq!(render(plan.candidate()), "foo bar");
    }

    #[test]
    fn concatenation_preserves_a_shorter_costlier_frontier_layout() {
        let cheap_long = Doc::text("12345");
        let costly_short = Doc::newline().append(Doc::text("x"));
        let tradeoff = Doc::choice(cheap_long, costly_short);
        let document = Doc::text("a").append(tradeoff).append(Doc::text("ZZZZZZ"));
        let plan = pick(&document, &Cost::f1(6));

        assert_eq!(render(plan.candidate()), "a\nxZZZZZZ");
        assert_eq!(plan.candidate().rank().overflow(), 1);
        assert_eq!(plan.candidate().rank().height(), 1);
    }

    #[test]
    fn nest_context_reaches_a_concatenation_tail() {
        let tail = Doc::cat([
            Doc::newline(),
            Doc::text("12345"),
            Doc::newline(),
            Doc::text("b"),
        ]);
        let document = Doc::nest(2, Doc::text("a").append(tail));
        let plan = pick(&document, &Cost::f1(6));

        assert_eq!(render(plan.candidate()), "a\n  12345\n  b");
        assert_eq!(plan.candidate().last_column(), 3);
        assert_eq!(plan.candidate().rank(), Rank::new(1, 4, 2));
    }

    #[test]
    fn verbatim_blocks_ignore_surrounding_indentation() {
        let document = Doc::text("ab").append(Doc::nest(
            2,
            Doc::cat([Doc::newline(), Doc::verbatim("x\ny"), Doc::text(" z")]),
        ));

        assert_eq!(format_document(&document, &Cost::f1(20)), "ab\n  x\ny z");
    }

    #[test]
    fn squared_overflow_matches_the_paper_example() {
        let one_line = pick(&Doc::text("   = func( pretty, print )"), &Cost::f2(6));
        assert_eq!(one_line.candidate().rank().overflow(), 400);

        let multiline = Doc::nest(
            2,
            Doc::cat([
                Doc::text("   = func("),
                Doc::newline(),
                Doc::text("pretty,"),
                Doc::newline(),
                Doc::text("print"),
            ]),
        )
        .append(Doc::newline())
        .append(Doc::text(")"));
        let plan = pick(&multiline, &Cost::f2(6));

        assert_eq!(
            render(plan.candidate()),
            "   = func(\n  pretty,\n  print\n)"
        );
        assert_eq!(plan.candidate().rank(), Rank::new(26, 4, 3));
    }

    #[test]
    fn frontiers_are_unrestricted() {
        let wide = Doc::text("123456789");
        let middle = Doc::newline().append(Doc::text("12345"));
        let narrow = Doc::cat([Doc::newline(), Doc::newline(), Doc::text("1")]);
        let document = Doc::choice(wide, Doc::choice(middle, narrow));
        let plan = pick(&document, &Cost::f1(100));

        assert_eq!(plan.frontier().len(), 3);
        assert_eq!(plan.statistics().frontier_maximum(), 3);
        assert_eq!(render(plan.candidate()), "123456789");
    }

    #[test]
    fn alignment_tracks_the_current_column() {
        fn document() -> Doc {
            let body = Doc::text("a").append(Doc::newline()).append(Doc::text("b"));
            Doc::text("xx").append(Doc::align(body.group()))
        }

        assert_eq!(format_document(&document(), &Cost::f1(20)), "xxa b");
        assert_eq!(format_document(&document(), &Cost::f1(3)), "xxa\n  b");
    }

    #[test]
    fn custom_text_cost_is_supported() {
        let cost = Cost::with_measure(80, |_, _, length| usize::from(length != 0));
        let document = Doc::text("one").append(Doc::text("two"));
        let plan = pick(&document, &cost);

        assert_eq!(plan.candidate().rank().overflow(), 2);
    }

    #[test]
    fn shared_memo_checkpoint_is_reused() {
        let mut shared = Doc::text("a");
        for _ in 0..6 {
            shared = shared.append(Doc::text("a"));
        }
        let document = Doc::choice(shared.clone(), shared);
        let plan = pick(&document, &Cost::f1(80));

        assert_eq!(render(plan.candidate()), "aaaaaaa");
        assert_eq!(plan.statistics().memo_hits(), 1);
        assert_eq!(plan.statistics().memo_entries(), 1);
    }

    #[test]
    fn unavoidable_overflow_is_deferred_and_forced() {
        let options = PickOptions {
            computation_width: Some(4),
            ..PickOptions::default()
        };
        let plan = pick_with_options(&Doc::text("abcdefgh"), &Cost::f1(4), options);

        assert_eq!(render(plan.candidate()), "abcdefgh");
        assert_eq!(plan.candidate().rank().overflow(), 4);
        assert!(plan.is_tainted());
        assert_eq!(plan.statistics().taints_deferred(), 1);
        assert_eq!(plan.statistics().taints_forced(), 1);
    }

    #[test]
    fn a_bounded_choice_beats_a_deferred_choice() {
        let document = Doc::choice(Doc::text("abcdefgh"), Doc::text("ok"));
        let plan = pick_with_options(
            &document,
            &Cost::f1(4),
            PickOptions {
                computation_width: Some(4),
                ..PickOptions::default()
            },
        );

        assert_eq!(render(plan.candidate()), "ok");
        assert!(!plan.is_tainted());
        assert!(plan.statistics().taints_deferred() >= 1);
        assert_eq!(plan.statistics().taints_forced(), 0);
    }

    #[test]
    fn forced_computation_becomes_bounded_after_a_newline() {
        let suffix = Doc::choice(Doc::text("abcdefgh"), Doc::text("ok"));
        let document = Doc::cat([Doc::text("abcdefgh"), Doc::newline(), suffix]);
        let plan = pick_with_options(
            &document,
            &Cost::f1(4),
            PickOptions {
                computation_width: Some(4),
                ..PickOptions::default()
            },
        );

        assert_eq!(render(plan.candidate()), "abcdefgh\nok");
        assert!(plan.is_tainted());
        assert!(plan.statistics().taints_forced() >= 1);
    }

    struct RecordingSink {
        text: String,
        events: Vec<String>,
    }

    impl RenderSink<&'static str> for RecordingSink {
        type Error = std::convert::Infallible;

        fn write_str(&mut self, text: &str) -> Result<(), Self::Error> {
            self.text.push_str(text);
            Ok(())
        }

        fn begin_span(&mut self, metadata: &&'static str) -> Result<(), Self::Error> {
            self.events.push(format!("open:{metadata}"));
            Ok(())
        }

        fn end_span(&mut self, metadata: &&'static str) -> Result<(), Self::Error> {
            self.events.push(format!("close:{metadata}"));
            Ok(())
        }
    }

    #[test]
    fn spans_survive_selection_without_affecting_cost() {
        type Annotated = Document<&'static str>;

        let body = Annotated::text("b")
            .append(Annotated::newline())
            .append(Annotated::text("c"))
            .group();
        let document = Annotated::cat([
            Annotated::text("a"),
            Annotated::span("hot", body),
            Annotated::text("d"),
        ]);
        let plan = pick(&document, &Cost::f1(10));
        let mut sink = RecordingSink {
            text: String::new(),
            events: Vec::new(),
        };

        assert_eq!(render(plan.candidate()), "ab cd");
        render_with(plan.candidate(), &mut sink).unwrap();
        assert_eq!(sink.text, "ab cd");
        assert_eq!(sink.events, ["open:hot", "close:hot"]);
    }
}
