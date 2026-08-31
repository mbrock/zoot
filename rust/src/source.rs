//! Formatting Rust source with a lossless, Rowan-based syntax tree.
//!
//! This module is available with the `rust-format` Cargo feature.

use ra_ap_syntax::{Edition, NodeOrToken, SourceFile, SyntaxKind, SyntaxToken};

use crate::{format_document, Cost, Doc};

const INDENT: usize = 4;

/// Format Rust source optimally for `width` columns.
///
/// Parsing uses rust-analyzer's lossless Rowan syntax tree. Formatting only
/// replaces whitespace: all other tokens, including comments, are emitted in
/// their original order and with their original spelling. Invalid source is
/// still formatted from the parser's recovery tree.
#[must_use]
pub fn format_source(source: &str, width: usize) -> String {
    let parse = SourceFile::parse(source, Edition::CURRENT);
    let tokens = parse
        .syntax_node()
        .descendants_with_tokens()
        .filter_map(NodeOrToken::into_token)
        .collect::<Vec<_>>();
    let mut parser = TokenTreeParser::new(tokens);
    let items = parser.sequence(None);

    if items.is_empty() {
        return String::new();
    }

    let document = sequence_doc(&items, SequenceMode::Top).append(Doc::newline());
    format_document(&document, &Cost::f2(width))
}

#[derive(Clone, Copy, Default)]
struct LeadingWhitespace {
    spaces: bool,
    newlines: usize,
}

struct Item {
    leading: LeadingWhitespace,
    kind: ItemKind,
}

enum ItemKind {
    Token {
        kind: SyntaxKind,
        text: String,
        parent: SyntaxKind,
        closure_pipe: Option<ClosurePipe>,
    },
    Group(Group),
}

#[derive(Clone, Copy, Eq, PartialEq)]
enum ClosurePipe {
    Opening,
    Closing,
}

struct Group {
    opening: String,
    closing: Option<String>,
    items: Vec<Item>,
    parent: SyntaxKind,
}

struct TokenTreeParser {
    tokens: Vec<SyntaxToken>,
    position: usize,
    whitespace: LeadingWhitespace,
}

impl TokenTreeParser {
    fn new(tokens: Vec<SyntaxToken>) -> Self {
        Self {
            tokens,
            position: 0,
            whitespace: LeadingWhitespace::default(),
        }
    }

    fn sequence(&mut self, closing: Option<SyntaxKind>) -> Vec<Item> {
        let mut items = Vec::new();
        while let Some(token) = self.tokens.get(self.position).cloned() {
            if token.kind() == SyntaxKind::WHITESPACE {
                self.record_whitespace(token.text());
                self.position += 1;
                continue;
            }
            if Some(token.kind()) == closing {
                self.position += 1;
                self.whitespace = LeadingWhitespace::default();
                break;
            }

            let leading = std::mem::take(&mut self.whitespace);
            if let Some(close) = matching_close(&token) {
                self.position += 1;
                let parent = token.parent().map_or(SyntaxKind::ERROR, |node| node.kind());
                let children = self.sequence(Some(close));
                let closing = self
                    .position
                    .checked_sub(1)
                    .and_then(|index| self.tokens.get(index))
                    .filter(|token| token.kind() == close)
                    .map(|token| token.text().to_owned());
                items.push(Item {
                    leading,
                    kind: ItemKind::Group(Group {
                        opening: token.text().to_owned(),
                        closing,
                        items: children,
                        parent,
                    }),
                });
            } else {
                self.position += 1;
                let closure_pipe = closure_pipe(&token);
                items.push(Item {
                    leading,
                    kind: ItemKind::Token {
                        kind: token.kind(),
                        text: token.text().to_owned(),
                        parent: token.parent().map_or(SyntaxKind::ERROR, |node| node.kind()),
                        closure_pipe,
                    },
                });
            }
        }
        items
    }

    fn record_whitespace(&mut self, text: &str) {
        self.whitespace.spaces |= !text.is_empty();
        self.whitespace.newlines += text.bytes().filter(|byte| *byte == b'\n').count();
    }
}

fn matching_close(token: &SyntaxToken) -> Option<SyntaxKind> {
    match token.kind() {
        SyntaxKind::L_PAREN => Some(SyntaxKind::R_PAREN),
        SyntaxKind::L_BRACK => Some(SyntaxKind::R_BRACK),
        SyntaxKind::L_CURLY => Some(SyntaxKind::R_CURLY),
        SyntaxKind::L_ANGLE if token.parent().is_some_and(|node| generic_list(node.kind())) => {
            Some(SyntaxKind::R_ANGLE)
        }
        _ => None,
    }
}

fn generic_list(kind: SyntaxKind) -> bool {
    matches!(
        kind,
        SyntaxKind::GENERIC_ARG_LIST | SyntaxKind::GENERIC_PARAM_LIST
    )
}

#[derive(Clone, Copy, Eq, PartialEq)]
enum SequenceMode {
    Top,
    Normal,
    Flat,
    Broken,
    Block,
}

fn sequence_doc(items: &[Item], mode: SequenceMode) -> Doc {
    let Some((first, rest)) = items.split_first() else {
        return Doc::empty();
    };
    let mut document = item_doc(first);

    for (index, item) in rest.iter().enumerate() {
        let previous = &items[index];
        document = document
            .append(separator_doc(previous, item, mode))
            .append(item_doc(item));
    }
    document
}

fn item_doc(item: &Item) -> Doc {
    match &item.kind {
        ItemKind::Token { text, .. } => Doc::verbatim(text.clone()),
        ItemKind::Group(group) => group_doc(group),
    }
}

fn group_doc(group: &Group) -> Doc {
    if group.items.is_empty() {
        return Doc::text(format!(
            "{}{}",
            group.opening,
            group.closing.as_deref().unwrap_or_default()
        ));
    }

    match group.opening.as_str() {
        "{" => brace_doc(group),
        "(" | "[" | "<" => delimited_doc(group),
        _ => Doc::cat([
            Doc::text(group.opening.clone()),
            sequence_doc(&group.items, SequenceMode::Normal),
            Doc::text(group.closing.clone().unwrap_or_default()),
        ]),
    }
}

fn delimited_doc(group: &Group) -> Doc {
    let flat = Doc::cat([
        Doc::text(group.opening.clone()),
        sequence_doc(&group.items, SequenceMode::Flat),
        Doc::text(group.closing.clone().unwrap_or_default()),
    ]);
    if can_flatten(&group.items) && !contains_comma(&group.items) {
        return flat;
    }

    let broken = Doc::cat([
        Doc::text(group.opening.clone()),
        Doc::nest(
            INDENT,
            Doc::newline().append(sequence_doc(&group.items, SequenceMode::Broken)),
        ),
        Doc::newline(),
        Doc::text(group.closing.clone().unwrap_or_default()),
    ]);
    if !can_flatten(&group.items) {
        return broken;
    }
    Doc::choice(flat, broken)
}

fn brace_doc(group: &Group) -> Doc {
    let broken = Doc::cat([
        Doc::text(group.opening.clone()),
        Doc::nest(
            INDENT,
            Doc::newline().append(sequence_doc(&group.items, SequenceMode::Block)),
        ),
        Doc::newline(),
        Doc::text(group.closing.clone().unwrap_or_default()),
    ]);

    if hard_vertical_braces(group.parent)
        || !can_flatten(&group.items)
        || has_trailing_comma(&group.items)
    {
        return broken;
    }

    let padded = group.parent != SyntaxKind::USE_TREE_LIST;
    let flat = Doc::cat([
        Doc::text(if padded { "{ " } else { "{" }),
        sequence_doc(&group.items, SequenceMode::Flat),
        Doc::text(
            group
                .closing
                .as_ref()
                .map_or("", |_| if padded { " }" } else { "}" }),
        ),
    ]);
    Doc::choice(flat, broken)
}

fn hard_vertical_braces(kind: SyntaxKind) -> bool {
    matches!(
        kind,
        SyntaxKind::BLOCK_EXPR
            | SyntaxKind::STMT_LIST
            | SyntaxKind::ITEM_LIST
            | SyntaxKind::ASSOC_ITEM_LIST
            | SyntaxKind::EXTERN_ITEM_LIST
            | SyntaxKind::MATCH_ARM_LIST
            | SyntaxKind::RECORD_FIELD_LIST
            | SyntaxKind::VARIANT_LIST
    )
}

fn separator_doc(previous: &Item, current: &Item, mode: SequenceMode) -> Doc {
    if current.leading.newlines >= 2 {
        return Doc::verbatim("\n").append(Doc::newline());
    }
    if is_line_comment(previous) {
        return Doc::newline();
    }
    if is_comment(current) && current.leading.newlines > 0 {
        return Doc::newline();
    }
    if is_comment(current) {
        return Doc::text(" ");
    }
    if matches!(mode, SequenceMode::Top) && current.leading.newlines > 0 {
        return Doc::newline();
    }
    if matches!(mode, SequenceMode::Top | SequenceMode::Block)
        && (is_semicolon(previous) || ends_block(previous, current) || ends_attribute(previous))
    {
        return Doc::newline();
    }
    if is_comma(previous) {
        return match mode {
            SequenceMode::Broken | SequenceMode::Block => Doc::newline(),
            SequenceMode::Normal => Doc::choice(Doc::text(" "), Doc::newline()),
            SequenceMode::Top | SequenceMode::Flat => Doc::text(" "),
        };
    }
    if needs_space(previous, current) {
        Doc::text(" ")
    } else {
        Doc::empty()
    }
}

fn needs_space(previous: &Item, current: &Item) -> bool {
    let left = last_text(previous);
    let right = first_text(current);

    if matches!(right, "," | ";" | "." | "::" | ")" | "]" | "}")
        || matches!(left, "(" | "[" | "{" | "." | "::" | "#" | "$")
        || matches!(left, "!" | "&" | "*") && !current.leading.spaces
        || matches!(right, "!" | "?" | ":")
    {
        return false;
    }
    if left == ">" && right == "(" && is_generic_delimiter(previous) {
        return false;
    }
    if closure_pipe_role(current).is_some()
        || closure_pipe_role(previous) == Some(ClosurePipe::Opening)
    {
        return false;
    }
    if closure_pipe_role(previous) == Some(ClosurePipe::Closing) {
        return true;
    }
    if is_operator(left) {
        return true;
    }
    if right == "(" && group_follows_keyword(previous, current) {
        return true;
    }
    if right == "(" || right == "[" {
        return false;
    }
    if right == "<" && is_generic_delimiter(current)
        || left == "<" && is_generic_delimiter(previous)
        || right == ">" && is_generic_delimiter(current)
    {
        return false;
    }
    if left == ":" {
        return is_type_colon(previous) || current.leading.spaces;
    }
    if is_operator(left) || is_operator(right) {
        return true;
    }
    if is_comment(previous) || is_comment(current) {
        return true;
    }
    word_like(previous) && word_like(current) || right == "{"
}

fn is_operator(text: &str) -> bool {
    matches!(
        text,
        "=" | "=="
            | "!="
            | "+"
            | "-"
            | "*"
            | "/"
            | "%"
            | "<"
            | ">"
            | "<="
            | ">="
            | "&&"
            | "||"
            | "&"
            | "|"
            | "^"
            | "<<"
            | ">>"
            | "+="
            | "-="
            | "*="
            | "/="
            | "%="
            | "&="
            | "|="
            | "^="
            | "<<="
            | ">>="
            | "->"
            | "=>"
    )
}

fn word_like(item: &Item) -> bool {
    match &item.kind {
        ItemKind::Group(_) => true,
        ItemKind::Token { kind, .. } => {
            matches!(
                kind,
                SyntaxKind::IDENT
                    | SyntaxKind::UNDERSCORE
                    | SyntaxKind::LIFETIME_IDENT
                    | SyntaxKind::INT_NUMBER
                    | SyntaxKind::FLOAT_NUMBER
                    | SyntaxKind::STRING
                    | SyntaxKind::BYTE_STRING
                    | SyntaxKind::C_STRING
                    | SyntaxKind::CHAR
                    | SyntaxKind::BYTE
            ) || kind.is_keyword(Edition::CURRENT)
        }
    }
}

fn first_text(item: &Item) -> &str {
    match &item.kind {
        ItemKind::Token { text, .. } => text,
        ItemKind::Group(group) => &group.opening,
    }
}

fn last_text(item: &Item) -> &str {
    match &item.kind {
        ItemKind::Token { text, .. } => text,
        ItemKind::Group(group) => group.closing.as_deref().unwrap_or(&group.opening),
    }
}

fn is_comment(item: &Item) -> bool {
    matches!(
        item.kind,
        ItemKind::Token {
            kind: SyntaxKind::COMMENT,
            ..
        }
    )
}

fn is_line_comment(item: &Item) -> bool {
    matches!(
        &item.kind,
        ItemKind::Token {
            kind: SyntaxKind::COMMENT,
            text,
            ..
        } if text.starts_with("//")
    )
}

fn is_comma(item: &Item) -> bool {
    first_text(item) == ","
}

fn is_semicolon(item: &Item) -> bool {
    first_text(item) == ";"
}

fn contains_comma(items: &[Item]) -> bool {
    items.iter().any(is_comma)
}

fn has_trailing_comma(items: &[Item]) -> bool {
    items.last().is_some_and(is_comma)
}

fn can_flatten(items: &[Item]) -> bool {
    items.iter().all(|item| {
        item.leading.newlines < 2
            && !is_line_comment(item)
            && match &item.kind {
                ItemKind::Token { text, .. } => !text.contains('\n'),
                ItemKind::Group(group) => can_flatten(&group.items),
            }
    })
}

fn ends_block(previous: &Item, current: &Item) -> bool {
    matches!(
        &previous.kind,
        ItemKind::Group(Group { parent, .. }) if hard_vertical_braces(*parent)
    ) && !matches!(first_text(current), "else" | "." | "?" | "," | ";")
}

fn ends_attribute(item: &Item) -> bool {
    matches!(
        &item.kind,
        ItemKind::Group(Group {
            parent: SyntaxKind::ATTR,
            ..
        })
    )
}

fn is_generic_delimiter(item: &Item) -> bool {
    match &item.kind {
        ItemKind::Token { parent, .. } | ItemKind::Group(Group { parent, .. }) => {
            generic_list(*parent)
        }
    }
}

fn is_type_colon(item: &Item) -> bool {
    matches!(
        &item.kind,
        ItemKind::Token {
            parent: SyntaxKind::PARAM
                | SyntaxKind::SELF_PARAM
                | SyntaxKind::RECORD_FIELD
                | SyntaxKind::RECORD_EXPR_FIELD
                | SyntaxKind::RECORD_PAT_FIELD,
            ..
        }
    )
}

fn closure_pipe(token: &SyntaxToken) -> Option<ClosurePipe> {
    let parent = token.parent()?;
    if token.kind() != SyntaxKind::PIPE || parent.kind() != SyntaxKind::PARAM_LIST {
        return None;
    }
    Some(if parent.first_token().as_ref() == Some(token) {
        ClosurePipe::Opening
    } else {
        ClosurePipe::Closing
    })
}

fn closure_pipe_role(item: &Item) -> Option<ClosurePipe> {
    match &item.kind {
        ItemKind::Token { closure_pipe, .. } => *closure_pipe,
        ItemKind::Group(_) => None,
    }
}

fn group_follows_keyword(previous: &Item, current: &Item) -> bool {
    word_like(previous)
        && matches!(
            &current.kind,
            ItemKind::Group(Group {
                parent: SyntaxKind::PAREN_EXPR
                    | SyntaxKind::TUPLE_EXPR
                    | SyntaxKind::PAREN_PAT
                    | SyntaxKind::TUPLE_PAT,
                ..
            })
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn format(source: &str, width: usize) -> String {
        format_source(source, width)
    }

    #[test]
    fn formats_functions_and_statements() {
        let source = "fn main(){let answer=add(20,22);println!(\"{answer}\");}";
        assert_eq!(
            format(source, 80),
            "fn main() {\n    let answer = add(20, 22);\n    println!(\"{answer}\");\n}\n"
        );
    }

    #[test]
    fn width_selects_broken_arguments() {
        let source = "fn call(){consume(first_argument,second_argument,third_argument);}";
        assert_eq!(
            format(source, 36),
            concat!(
                "fn call() {\n",
                "    consume(\n",
                "        first_argument,\n",
                "        second_argument,\n",
                "        third_argument\n",
                "    );\n",
                "}\n"
            )
        );
    }

    #[test]
    fn preserves_comments_and_blank_lines() {
        let source = "// heading\nfn f(){let x=1; // why\n\n/* keep */ x+1;}\n";
        assert_eq!(
            format(source, 80),
            concat!(
                "// heading\n",
                "fn f() {\n",
                "    let x = 1; // why\n",
                "\n",
                "    /* keep */ x + 1;\n",
                "}\n"
            )
        );
    }

    #[test]
    fn keeps_delimiters_after_line_comments_active() {
        let source = "fn f(){match x{Some(Binary(A|// note\nB))=>true,_=>false,}}";
        assert_round_trip("line comment before delimiters", source, 80);
    }

    #[test]
    fn keeps_attributes_and_generic_arguments_tight() {
        let source = "#[inline]fn identity<T>(value:Option<T>)->Option<T>{value}";
        assert_eq!(
            format(source, 80),
            concat!(
                "#[inline]\n",
                "fn identity<T>(value: Option<T>) -> Option<T> {\n",
                "    value\n",
                "}\n"
            )
        );
    }

    #[test]
    fn formats_enum_variants_from_their_syntax() {
        let source = concat!(
            "use std::collections::{BTreeMap,HashMap};",
            "enum Deferred<A>{",
            "Document{document:Document<A>,last:usize,base:usize,},",
            "Wrap{wrapper:Wrapper<A>,evaluation:Evaluation<A>,},",
            "}"
        );
        assert_eq!(
            format(source, 80),
            concat!(
                "use std::collections::{BTreeMap, HashMap};\n",
                "enum Deferred<A> {\n",
                "    Document {\n",
                "        document: Document<A>,\n",
                "        last: usize,\n",
                "        base: usize,\n",
                "    },\n",
                "    Wrap {\n",
                "        wrapper: Wrapper<A>,\n",
                "        evaluation: Evaluation<A>,\n",
                "    },\n",
                "}\n"
            )
        );
    }

    #[test]
    fn formats_patterns_and_closures_from_their_syntax() {
        let source = concat!(
            "fn transform(values:Vec<i32>){",
            "for(index,value)in values.into_iter().enumerate(){",
            "let mapped=Some(value).unwrap_or_else(||0);",
            "consume(index,mapped.map(|item|item+1));",
            "}",
            "}"
        );
        assert_eq!(
            format(source, 80),
            concat!(
                "fn transform(values: Vec<i32>) {\n",
                "    for (index, value) in values.into_iter().enumerate() {\n",
                "        let mapped = Some(value).unwrap_or_else(|| 0);\n",
                "        consume(index, mapped.map(|item| item + 1));\n",
                "    }\n",
                "}\n"
            )
        );
    }

    #[test]
    fn real_sources_round_trip_at_multiple_widths() {
        let sources = [
            ("cost.rs", include_str!("cost.rs")),
            ("document.rs", include_str!("document.rs")),
            ("evaluator.rs", include_str!("evaluator.rs")),
            ("lib.rs", include_str!("lib.rs")),
            ("render.rs", include_str!("render.rs")),
            ("source.rs", include_str!("source.rs")),
            (
                "examples/large_array.rs",
                include_str!("../examples/large_array.rs"),
            ),
        ];

        for (name, source) in sources {
            let input_errors = SourceFile::parse(source, Edition::CURRENT).errors();
            assert!(
                input_errors.is_empty(),
                "{name} is not valid: {input_errors:#?}"
            );

            for width in [40, 80, 120] {
                assert_round_trip(name, source, width);
            }
        }
    }

    #[test]
    fn rustc_parser_sample_round_trips() {
        std::thread::Builder::new()
            .stack_size(32 * 1024 * 1024)
            .spawn(|| {
                let source = include_str!("../samples/rustc_parse_expr.rs");
                let input_errors = SourceFile::parse(source, Edition::CURRENT).errors();
                assert!(
                    input_errors.is_empty(),
                    "rustc parser sample is not valid: {input_errors:#?}"
                );
                assert_round_trip("rustc parser sample", source, 100);
            })
            .expect("failed to spawn large-stack formatter test")
            .join()
            .expect("large-stack formatter test panicked");
    }

    #[test]
    fn does_not_synthesize_tokens_for_incomplete_source() {
        let source = "fn unfinished(value: Option<T> { value";
        let output = format(source, 80);
        assert_eq!(non_whitespace_text(source), non_whitespace_text(&output));
    }

    fn assert_round_trip(name: &str, source: &str, width: usize) {
        let output = format(source, width);
        assert_eq!(
            non_whitespace_text(source),
            non_whitespace_text(&output),
            "formatting {name} at width {width} changed its tokens"
        );

        let output_errors = SourceFile::parse(&output, Edition::CURRENT).errors();
        assert!(
            output_errors.is_empty(),
            "formatting {name} at width {width} produced invalid Rust: {output_errors:#?}\n{output}"
        );
        assert_eq!(
            format(&output, width),
            output,
            "formatting {name} at width {width} is not idempotent"
        );
    }

    fn non_whitespace_text(source: &str) -> String {
        SourceFile::parse(source, Edition::CURRENT)
            .syntax_node()
            .descendants_with_tokens()
            .filter_map(NodeOrToken::into_token)
            .filter(|token| token.kind() != SyntaxKind::WHITESPACE)
            .map(|token| token.text().to_owned())
            .collect()
    }
}
