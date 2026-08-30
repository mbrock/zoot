use std::sync::Arc;

const INITIAL_MEMO_WEIGHT: usize = 6;

/// A layout search space built from text, line breaks, concatenation, and
/// arbitrary choices.
///
/// Cloning a document is cheap and preserves sharing. The annotation type is
/// used only by [`Document::span`]; it defaults to `()` for plain documents.
pub struct Document<A = ()>(pub(crate) Arc<Node<A>>);

impl<A> Clone for Document<A> {
    fn clone(&self) -> Self {
        Self(Arc::clone(&self.0))
    }
}

pub(crate) enum Node<A> {
    Text(String),
    Verbatim(String),
    Newline,
    Concat(Document<A>, Document<A>),
    Choice(Document<A>, Document<A>),
    Nest(usize, Document<A>),
    Align(Document<A>),
    Span(Arc<A>, Document<A>),
    Memo(Document<A>),
}

impl<A> Document<A> {
    /// Construct an empty document.
    #[must_use]
    pub fn empty() -> Self {
        Self::raw(Node::Text(String::new()))
    }

    /// Construct a text terminal.
    ///
    /// Text terminals cannot contain newlines; use [`Document::verbatim`] for
    /// literal multiline content.
    ///
    /// # Panics
    ///
    /// Panics when `text` contains a newline.
    #[must_use]
    pub fn text(text: impl Into<String>) -> Self {
        let text = text.into();
        assert!(
            !text.contains('\n'),
            "text terminals cannot contain newlines"
        );
        Self::raw(Node::Text(text))
    }

    /// Construct a literal text block. Newlines inside the block start at
    /// column zero and cannot be flattened.
    #[must_use]
    pub fn verbatim(text: impl Into<String>) -> Self {
        let text = text.into();
        if text.contains('\n') {
            Self::raw(Node::Verbatim(text))
        } else {
            Self::raw(Node::Text(text))
        }
    }

    /// Construct a hard line break.
    #[must_use]
    pub fn newline() -> Self {
        Self::raw(Node::Newline)
    }

    /// Place `right` immediately after `self`.
    #[must_use]
    pub fn append(self, right: Self) -> Self {
        Self::checkpointed(Node::Concat(self, right))
    }

    /// Construct an arbitrary choice between two layouts.
    #[must_use]
    pub fn choice(left: Self, right: Self) -> Self {
        Self::checkpointed(Node::Choice(left, right))
    }

    /// Indent lines after the first by `amount` columns.
    #[must_use]
    pub fn nest(amount: usize, document: Self) -> Self {
        if amount == 0 {
            document
        } else {
            Self::checkpointed(Node::Nest(amount, document))
        }
    }

    /// Use the current column as `document`'s indentation base.
    #[must_use]
    pub fn align(document: Self) -> Self {
        Self::checkpointed(Node::Align(document))
    }

    /// Attach opaque metadata to a document without affecting layout search.
    #[must_use]
    pub fn span(metadata: A, document: Self) -> Self {
        Self::checkpointed(Node::Span(Arc::new(metadata), document))
    }

    /// Concatenate all documents in iteration order.
    #[must_use]
    pub fn cat(documents: impl IntoIterator<Item = Self>) -> Self {
        documents.into_iter().fold(Self::empty(), Self::append)
    }

    /// Concatenate all documents with hard line breaks between them.
    #[must_use]
    pub fn vcat(documents: impl IntoIterator<Item = Self>) -> Self {
        Self::separated_by(&Self::newline(), documents)
    }

    /// Concatenate documents with `separator` between adjacent items.
    #[must_use]
    pub fn separated_by(separator: &Self, documents: impl IntoIterator<Item = Self>) -> Self {
        let mut documents = documents.into_iter();
        let Some(first) = documents.next() else {
            return Self::empty();
        };
        documents.fold(first, |left, right| {
            left.append(separator.clone()).append(right)
        })
    }

    /// Place one space between adjacent documents.
    #[must_use]
    pub fn separated_by_spaces(documents: impl IntoIterator<Item = Self>) -> Self {
        Self::separated_by(&Self::text(" "), documents)
    }

    /// Place one hard line break between adjacent documents.
    #[must_use]
    pub fn one_per_line(documents: impl IntoIterator<Item = Self>) -> Self {
        Self::separated_by(&Self::newline(), documents)
    }

    /// Place a document between opening and closing documents.
    #[must_use]
    pub fn surrounded_by(opening: Self, closing: Self, document: Self) -> Self {
        opening.append(document).append(closing)
    }

    /// Place a document between parentheses.
    #[must_use]
    pub fn in_parentheses(document: Self) -> Self {
        Self::surrounded_by(Self::text("("), Self::text(")"), document)
    }

    /// Place a document between square brackets.
    #[must_use]
    pub fn in_square_brackets(document: Self) -> Self {
        Self::surrounded_by(Self::text("["), Self::text("]"), document)
    }

    /// Place a document between braces.
    #[must_use]
    pub fn in_braces(document: Self) -> Self {
        Self::surrounded_by(Self::text("{"), Self::text("}"), document)
    }

    /// Precede a document with a hard line break.
    #[must_use]
    pub fn starting_on_next_line(document: Self) -> Self {
        Self::newline().append(document)
    }

    /// Replace hard line breaks with spaces and remove nesting.
    ///
    /// Choices and alignment are preserved, while verbatim blocks remain
    /// unchanged.
    #[must_use]
    pub fn flatten(&self) -> Self {
        match self.node() {
            Node::Text(_) | Node::Verbatim(_) => self.clone(),
            Node::Newline => Self::text(" "),
            Node::Concat(left, right) => Self::raw(Node::Concat(left.flatten(), right.flatten())),
            Node::Choice(left, right) => Self::raw(Node::Choice(left.flatten(), right.flatten())),
            Node::Nest(_, child) => child.flatten(),
            Node::Align(child) => Self::raw(Node::Align(child.flatten())),
            Node::Span(metadata, child) => {
                Self::raw(Node::Span(Arc::clone(metadata), child.flatten()))
            }
            Node::Memo(child) => Self::raw(Node::Memo(child.flatten())),
        }
    }

    /// Choose between this document and its flattened form.
    #[must_use]
    pub fn group(self) -> Self {
        let flattened = self.flatten();
        Self::choice(self, flattened)
    }

    pub(crate) fn node(&self) -> &Node<A> {
        &self.0
    }

    pub(crate) fn identity(&self) -> usize {
        Arc::as_ptr(&self.0) as usize
    }

    pub(crate) fn raw(node: Node<A>) -> Self {
        Self(Arc::new(node))
    }

    fn checkpointed(node: Node<A>) -> Self {
        let document = Self::raw(node);
        if memo_weight(&document) == 0 {
            Self::raw(Node::Memo(document))
        } else {
            document
        }
    }
}

fn memo_weight<A>(document: &Document<A>) -> usize {
    match document.node() {
        Node::Memo(_) => 0,
        Node::Concat(left, right) | Node::Choice(left, right) => {
            next_memo_weight(left).min(next_memo_weight(right))
        }
        Node::Nest(_, child) | Node::Align(child) | Node::Span(_, child) => next_memo_weight(child),
        Node::Text(_) | Node::Verbatim(_) | Node::Newline => INITIAL_MEMO_WEIGHT,
    }
}

fn next_memo_weight<A>(document: &Document<A>) -> usize {
    match memo_weight(document) {
        0 => INITIAL_MEMO_WEIGHT,
        weight => weight - 1,
    }
}
