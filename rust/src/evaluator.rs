use std::collections::{BTreeMap, HashMap};
use std::sync::Arc;

use crate::cost::{Cost, Rank};
use crate::document::{Document, Node};

/// Counters collected during one layout search.
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct Statistics {
    evaluations: usize,
    memo_hits: usize,
    memo_entries: usize,
    taints_deferred: usize,
    taints_forced: usize,
    frontier_maximum: usize,
    frontier_histogram: BTreeMap<usize, usize>,
}

impl Statistics {
    /// Number of non-memo document nodes evaluated.
    #[must_use]
    pub const fn evaluations(&self) -> usize {
        self.evaluations
    }

    /// Number of memo checkpoint hits.
    #[must_use]
    pub const fn memo_hits(&self) -> usize {
        self.memo_hits
    }

    /// Number of memo checkpoint entries created.
    #[must_use]
    pub const fn memo_entries(&self) -> usize {
        self.memo_entries
    }

    /// Number of computations deferred outside the computation width.
    #[must_use]
    pub const fn taints_deferred(&self) -> usize {
        self.taints_deferred
    }

    /// Number of deferred computations forced because overflow was unavoidable.
    #[must_use]
    pub const fn taints_forced(&self) -> usize {
        self.taints_forced
    }

    /// Largest Pareto frontier observed during evaluation.
    #[must_use]
    pub const fn frontier_maximum(&self) -> usize {
        self.frontier_maximum
    }

    /// Counts of observed frontier sizes.
    #[must_use]
    pub const fn frontier_histogram(&self) -> &BTreeMap<usize, usize> {
        &self.frontier_histogram
    }
}

/// Optional controls for a layout search.
#[derive(Clone, Copy, Debug)]
pub struct PickOptions {
    /// Explicit bounded-search width, or the cost's 1.2× default when absent.
    pub computation_width: Option<usize>,
    /// Whether structural memo checkpoints cache shared subproblems.
    pub memoize: bool,
}

impl Default for PickOptions {
    fn default() -> Self {
        Self {
            computation_width: None,
            memoize: true,
        }
    }
}

/// One point on a Pareto frontier.
pub struct Candidate<A = ()> {
    layout: Document<A>,
    last: usize,
    rank: Rank,
}

impl<A> Clone for Candidate<A> {
    fn clone(&self) -> Self {
        Self {
            layout: self.layout.clone(),
            last: self.last,
            rank: self.rank,
        }
    }
}

impl<A> Candidate<A> {
    /// The resolved, choice-free layout.
    #[must_use]
    pub const fn layout(&self) -> &Document<A> {
        &self.layout
    }

    /// The final output column.
    #[must_use]
    pub const fn last_column(&self) -> usize {
        self.last
    }

    /// The layout's optimization rank.
    #[must_use]
    pub const fn rank(&self) -> Rank {
        self.rank
    }
}

/// The completed result of resolving a document.
pub struct Plan<A = ()> {
    candidate: Candidate<A>,
    frontier: Vec<Candidate<A>>,
    statistics: Statistics,
    tainted: bool,
}

impl<A> Plan<A> {
    /// The lexicographically best candidate.
    #[must_use]
    pub const fn candidate(&self) -> &Candidate<A> {
        &self.candidate
    }

    /// The root's complete Pareto frontier, ordered by decreasing final column.
    #[must_use]
    pub fn frontier(&self) -> &[Candidate<A>] {
        &self.frontier
    }

    /// Search counters for this plan.
    #[must_use]
    pub const fn statistics(&self) -> &Statistics {
        &self.statistics
    }

    /// Whether the root had to force computation outside the bounded region.
    #[must_use]
    pub const fn is_tainted(&self) -> bool {
        self.tainted
    }
}

enum Evaluation<A> {
    Empty,
    Frontier(Vec<Candidate<A>>),
    Deferred(Box<Deferred<A>>),
}

impl<A> Clone for Evaluation<A> {
    fn clone(&self) -> Self {
        match self {
            Self::Empty => Self::Empty,
            Self::Frontier(frontier) => Self::Frontier(frontier.clone()),
            Self::Deferred(context) => Self::Deferred(Box::new(context.as_ref().clone())),
        }
    }
}

enum Deferred<A> {
    Document {
        document: Document<A>,
        last: usize,
        base: usize,
    },
    Wrap {
        wrapper: Wrapper<A>,
        evaluation: Evaluation<A>,
    },
    Right {
        left: Candidate<A>,
        evaluation: Evaluation<A>,
    },
    Left {
        document: Document<A>,
        base: usize,
        evaluation: Evaluation<A>,
    },
}

impl<A> Clone for Deferred<A> {
    fn clone(&self) -> Self {
        match self {
            Self::Document {
                document,
                last,
                base,
            } => Self::Document {
                document: document.clone(),
                last: *last,
                base: *base,
            },
            Self::Wrap {
                wrapper,
                evaluation,
            } => Self::Wrap {
                wrapper: wrapper.clone(),
                evaluation: evaluation.clone(),
            },
            Self::Right { left, evaluation } => Self::Right {
                left: left.clone(),
                evaluation: evaluation.clone(),
            },
            Self::Left {
                document,
                base,
                evaluation,
            } => Self::Left {
                document: document.clone(),
                base: *base,
                evaluation: evaluation.clone(),
            },
        }
    }
}

enum Wrapper<A> {
    Nest(usize),
    Align,
    Span(Arc<A>),
}

impl<A> Clone for Wrapper<A> {
    fn clone(&self) -> Self {
        match self {
            Self::Nest(amount) => Self::Nest(*amount),
            Self::Align => Self::Align,
            Self::Span(metadata) => Self::Span(Arc::clone(metadata)),
        }
    }
}

#[derive(Clone, Copy, Eq, Hash, PartialEq)]
struct MemoKey {
    document: usize,
    last: usize,
    base: usize,
}

struct Evaluator<'a, A> {
    cost: &'a Cost,
    limit: usize,
    memoize: bool,
    memo: HashMap<MemoKey, Evaluation<A>>,
    statistics: Statistics,
}

impl<'a, A> Evaluator<'a, A> {
    fn new(cost: &'a Cost, options: PickOptions) -> Self {
        Self {
            cost,
            limit: options
                .computation_width
                .unwrap_or_else(|| cost.default_computation_width()),
            memoize: options.memoize,
            memo: HashMap::new(),
            statistics: Statistics::default(),
        }
    }

    fn evaluate(&mut self, document: &Document<A>, last: usize, base: usize) -> Evaluation<A> {
        if let Node::Memo(child) = document.node() {
            if self.memoize && last <= self.limit && base <= self.limit {
                let key = MemoKey {
                    document: document.identity(),
                    last,
                    base,
                };
                if let Some(evaluation) = self.memo.get(&key).cloned() {
                    self.statistics.memo_hits += 1;
                    return evaluation;
                }
                let evaluation = self.evaluate(child, last, base);
                self.memo.insert(key, evaluation.clone());
                self.statistics.memo_entries += 1;
                return evaluation;
            }
            return self.evaluate(child, last, base);
        }

        self.statistics.evaluations += 1;
        if self.exceeds_computation_limit(document, last, base) {
            return self.defer(Deferred::Document {
                document: document.clone(),
                last,
                base,
            });
        }

        let evaluation = self.evaluate_document(document, last, base);
        self.note_evaluation(&evaluation);
        evaluation
    }

    fn evaluate_document(
        &mut self,
        document: &Document<A>,
        last: usize,
        base: usize,
    ) -> Evaluation<A> {
        match document.node() {
            Node::Text(text) => Evaluation::Frontier(vec![Candidate {
                layout: document.clone(),
                last: last.saturating_add(text.len()),
                rank: Rank::new(self.cost.text(last, text.len()), 0, 0),
            }]),
            Node::Verbatim(text) => {
                let mut overflow = 0usize;
                let mut height = 0usize;
                let mut column = last;
                for (index, line) in text.split('\n').enumerate() {
                    if index != 0 {
                        height = height.saturating_add(1);
                        column = 0;
                    }
                    overflow = overflow.saturating_add(self.cost.text(column, line.len()));
                    column = column.saturating_add(line.len());
                }
                Evaluation::Frontier(vec![Candidate {
                    layout: document.clone(),
                    last: column,
                    rank: Rank::new(overflow, 0, height),
                }])
            }
            Node::Newline => Evaluation::Frontier(vec![Candidate {
                layout: document.clone(),
                last: base,
                rank: Rank::new(0, base, 1),
            }]),
            Node::Concat(left, _) => self.evaluate_concatenation(document, left, last, base),
            Node::Choice(left, right) => {
                let left = self.evaluate(left, last, base);
                let right = self.evaluate(right, last, base);
                Self::merge_evaluations(left, right)
            }
            Node::Nest(amount, child) => {
                let evaluation = self.evaluate(child, last, base.saturating_add(*amount));
                self.wrap_evaluation(Wrapper::Nest(*amount), evaluation)
            }
            Node::Align(child) => {
                let evaluation = self.evaluate(child, last, last);
                self.wrap_evaluation(Wrapper::Align, evaluation)
            }
            Node::Span(metadata, child) => {
                let evaluation = self.evaluate(child, last, base);
                self.wrap_evaluation(Wrapper::Span(Arc::clone(metadata)), evaluation)
            }
            Node::Memo(child) => self.evaluate(child, last, base),
        }
    }

    fn evaluate_concatenation(
        &mut self,
        document: &Document<A>,
        left: &Document<A>,
        last: usize,
        base: usize,
    ) -> Evaluation<A> {
        let evaluation = self.evaluate(left, last, base);
        match evaluation {
            Evaluation::Empty => Evaluation::Empty,
            Evaluation::Deferred(_) => self.defer(Deferred::Left {
                document: document.clone(),
                base,
                evaluation,
            }),
            Evaluation::Frontier(frontier) => {
                let mut result = Evaluation::Empty;
                for candidate in frontier {
                    let right = self.concatenate_right(document, candidate, base);
                    result = Self::merge_evaluations(result, right);
                }
                result
            }
        }
    }

    fn concatenate_right(
        &mut self,
        document: &Document<A>,
        left: Candidate<A>,
        base: usize,
    ) -> Evaluation<A> {
        let Node::Concat(_, right) = document.node() else {
            unreachable!("a concatenation continuation must hold a concatenation")
        };
        let evaluation = self.evaluate(right, left.last, base);
        self.concatenate_right_evaluation(left, evaluation)
    }

    fn concatenate_right_evaluation(
        &mut self,
        left: Candidate<A>,
        right: Evaluation<A>,
    ) -> Evaluation<A> {
        match right {
            Evaluation::Empty => Evaluation::Empty,
            Evaluation::Deferred(_) => self.defer(Deferred::Right {
                left,
                evaluation: right,
            }),
            Evaluation::Frontier(frontier) => Evaluation::Frontier(
                frontier
                    .into_iter()
                    .map(|right| Self::concatenate_candidates(&left, right))
                    .collect(),
            ),
        }
    }

    fn concatenate_candidates(left: &Candidate<A>, right: Candidate<A>) -> Candidate<A> {
        Candidate {
            layout: Document::raw(Node::Concat(left.layout.clone(), right.layout)),
            last: right.last,
            rank: left.rank.plus(right.rank),
        }
    }

    fn wrap_evaluation(&mut self, wrapper: Wrapper<A>, evaluation: Evaluation<A>) -> Evaluation<A> {
        match evaluation {
            Evaluation::Empty => Evaluation::Empty,
            Evaluation::Deferred(_) => self.defer(Deferred::Wrap {
                wrapper,
                evaluation,
            }),
            Evaluation::Frontier(frontier) => Evaluation::Frontier(
                frontier
                    .into_iter()
                    .map(|candidate| Self::wrap_candidate(&wrapper, candidate))
                    .collect(),
            ),
        }
    }

    fn wrap_candidate(wrapper: &Wrapper<A>, candidate: Candidate<A>) -> Candidate<A> {
        let layout = match wrapper {
            Wrapper::Nest(amount) => Document::raw(Node::Nest(*amount, candidate.layout)),
            Wrapper::Align => Document::raw(Node::Align(candidate.layout)),
            Wrapper::Span(metadata) => {
                Document::raw(Node::Span(Arc::clone(metadata), candidate.layout))
            }
        };
        Candidate {
            layout,
            last: candidate.last,
            rank: candidate.rank,
        }
    }

    fn force(&mut self, evaluation: Evaluation<A>) -> Candidate<A> {
        match evaluation {
            Evaluation::Empty => panic!("cannot choose from an empty frontier"),
            Evaluation::Frontier(frontier) => frontier
                .into_iter()
                .next()
                .expect("a frontier is never empty"),
            Evaluation::Deferred(context) => {
                self.statistics.taints_forced += 1;
                match *context {
                    Deferred::Document {
                        document,
                        last,
                        base,
                    } => {
                        let evaluation = self.evaluate_document(&document, last, base);
                        self.note_evaluation(&evaluation);
                        self.force(evaluation)
                    }
                    Deferred::Wrap {
                        wrapper,
                        evaluation,
                    } => {
                        let candidate = self.force(evaluation);
                        Self::wrap_candidate(&wrapper, candidate)
                    }
                    Deferred::Right { left, evaluation } => {
                        let right = self.force(evaluation);
                        Self::concatenate_candidates(&left, right)
                    }
                    Deferred::Left {
                        document,
                        base,
                        evaluation,
                    } => {
                        let left = self.force(evaluation);
                        let right = self.concatenate_right(&document, left, base);
                        self.force(right)
                    }
                }
            }
        }
    }

    fn defer(&mut self, context: Deferred<A>) -> Evaluation<A> {
        self.statistics.taints_deferred += 1;
        Evaluation::Deferred(Box::new(context))
    }

    fn exceeds_computation_limit(&self, document: &Document<A>, last: usize, base: usize) -> bool {
        if base > self.limit || last > self.limit {
            return true;
        }
        match document.node() {
            Node::Text(text) => last.saturating_add(text.len()) > self.limit,
            _ => false,
        }
    }

    fn note_evaluation(&mut self, evaluation: &Evaluation<A>) {
        let Evaluation::Frontier(frontier) = evaluation else {
            return;
        };
        let length = frontier.len();
        self.statistics.frontier_maximum = self.statistics.frontier_maximum.max(length);
        *self
            .statistics
            .frontier_histogram
            .entry(length)
            .or_default() += 1;
    }

    fn merge_evaluations(left: Evaluation<A>, right: Evaluation<A>) -> Evaluation<A> {
        match (left, right) {
            (Evaluation::Empty, right)
            | (Evaluation::Deferred(_), right @ Evaluation::Frontier(_)) => right,
            (left, Evaluation::Empty | Evaluation::Deferred(_)) => left,
            (Evaluation::Frontier(left), Evaluation::Frontier(right)) => {
                Evaluation::Frontier(Self::merge_frontiers(&left, &right))
            }
        }
    }

    fn merge_frontiers(left: &[Candidate<A>], right: &[Candidate<A>]) -> Vec<Candidate<A>> {
        let mut result = Vec::with_capacity(left.len().saturating_add(right.len()));
        let mut left_index = 0;
        let mut right_index = 0;

        while left_index < left.len() && right_index < right.len() {
            let a = &left[left_index];
            let b = &right[right_index];
            if Self::dominates(a, b) {
                right_index += 1;
            } else if Self::dominates(b, a) {
                left_index += 1;
            } else if a.last > b.last {
                result.push(a.clone());
                left_index += 1;
            } else {
                result.push(b.clone());
                right_index += 1;
            }
        }
        result.extend(left[left_index..].iter().cloned());
        result.extend(right[right_index..].iter().cloned());
        result
    }

    fn dominates(left: &Candidate<A>, right: &Candidate<A>) -> bool {
        left.last <= right.last && left.rank <= right.rank
    }
}

/// Resolve a document with the default computation width and memoization.
#[must_use]
pub fn pick<A>(document: &Document<A>, cost: &Cost) -> Plan<A> {
    pick_with_options(document, cost, PickOptions::default())
}

/// Resolve a document while explicitly controlling bounded search and memoization.
///
/// # Panics
///
/// Panics only if an internally constructed document has no layouts. Every
/// document exposed by the public constructors has at least one layout.
#[must_use]
pub fn pick_with_options<A>(document: &Document<A>, cost: &Cost, options: PickOptions) -> Plan<A> {
    let mut evaluator = Evaluator::new(cost, options);
    let evaluation = evaluator.evaluate(document, 0, 0);
    let tainted = matches!(evaluation, Evaluation::Deferred(_));
    let frontier = match evaluation {
        Evaluation::Empty => panic!("document has no layouts"),
        Evaluation::Deferred(_) => vec![evaluator.force(evaluation)],
        Evaluation::Frontier(frontier) => frontier,
    };
    let candidate = frontier
        .iter()
        .min_by_key(|candidate| candidate.rank)
        .expect("document has no layouts")
        .clone();

    Plan {
        candidate,
        frontier,
        statistics: evaluator.statistics,
        tainted,
    }
}
