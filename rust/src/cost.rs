use std::sync::Arc;

type Measure = dyn Fn(usize, usize, usize) -> usize + Send + Sync;

/// A layout's lexicographic optimization rank.
#[derive(Clone, Copy, Debug, Default, Eq, Ord, PartialEq, PartialOrd)]
pub struct Rank {
    overflow: usize,
    indentation: usize,
    height: usize,
}

impl Rank {
    pub(crate) const fn new(overflow: usize, indentation: usize, height: usize) -> Self {
        Self {
            overflow,
            indentation,
            height,
        }
    }

    /// The accumulated line-overflow cost.
    #[must_use]
    pub const fn overflow(self) -> usize {
        self.overflow
    }

    /// The sum of indentation inserted after hard line breaks.
    #[must_use]
    pub const fn indentation(self) -> usize {
        self.indentation
    }

    /// The number of hard or verbatim line breaks.
    #[must_use]
    pub const fn height(self) -> usize {
        self.height
    }

    pub(crate) fn plus(self, other: Self) -> Self {
        Self {
            overflow: self.overflow.saturating_add(other.overflow),
            indentation: self.indentation.saturating_add(other.indentation),
            height: self.height.saturating_add(other.height),
        }
    }
}

/// A page width and text-overflow objective used during layout search.
#[derive(Clone)]
pub struct Cost {
    page_width: usize,
    measure: Arc<Measure>,
}

impl Cost {
    /// Minimize linear overflow, then indentation, then line count.
    #[must_use]
    pub fn f1(page_width: usize) -> Self {
        Self::with_measure(page_width, linear_overflow_cost)
    }

    /// Minimize squared overflow, then indentation, then line count.
    #[must_use]
    pub fn f2(page_width: usize) -> Self {
        Self::with_measure(page_width, squared_overflow_cost)
    }

    /// Construct a custom text objective. The function receives page width,
    /// starting column, and text length and returns a nonnegative cost.
    #[must_use]
    pub fn with_measure(
        page_width: usize,
        measure: impl Fn(usize, usize, usize) -> usize + Send + Sync + 'static,
    ) -> Self {
        Self {
            page_width,
            measure: Arc::new(measure),
        }
    }

    /// The preferred page width.
    #[must_use]
    pub const fn page_width(&self) -> usize {
        self.page_width
    }

    /// The default bounded-search width, 1.2 times the page width.
    #[must_use]
    pub fn default_computation_width(&self) -> usize {
        self.page_width.saturating_add(self.page_width / 5)
    }

    pub(crate) fn text(&self, column: usize, length: usize) -> usize {
        (self.measure)(self.page_width, column, length)
    }
}

/// Additional linear overflow caused by placing text at `column`.
#[must_use]
pub fn linear_overflow_cost(page_width: usize, column: usize, length: usize) -> usize {
    column
        .saturating_add(length)
        .saturating_sub(page_width.max(column))
}

/// Increase in squared line overflow caused by placing text at `column`.
#[must_use]
pub fn squared_overflow_cost(page_width: usize, column: usize, length: usize) -> usize {
    let old_overflow = column.saturating_sub(page_width);
    let new_text_overflow = column
        .saturating_add(length)
        .saturating_sub(page_width.max(column));
    new_text_overflow.saturating_mul(
        old_overflow
            .saturating_mul(2)
            .saturating_add(new_text_overflow),
    )
}
