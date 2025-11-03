/** <module> Heap Analysis Library

Reusable library for analyzing pretty printer heap dumps.
Provides proper node handle decoding and heap traversal.

@author Heap Inspector
@license MIT
*/

:- module(heap_lib, [
    decode_node_handle/2,
    node_type/2,
    node_item/2,
    trace_node/1,
    trace_node/2,
    render_tree/1,
    find_node_data/2,
    calculate_length/2
]).

:- style_check(-discontiguous).

%! decode_node_handle(+Handle:atom, -Decoded:compound) is det.
%  Decodes a node handle (like node_28006) into its components.
%
%  Tag encoding (3 bits):
%    0b000 (0) = span
%    0b001 (1) = quad
%    0b010 (2) = trip
%    0b011 (3) = rune
%    0b100 (4) = hcat
%    0b101 (5) = fork
%    0b110 (6) = cons
%
%  For oper nodes (hcat/fork/cons):
%    bits 3-9: frob (warp:1 + nest:6)
%    bit 10: flip
%    bits 11-31: item (21 bits)
%
%  For terminal nodes (span/quad/trip/rune):
%    bits 3-31: type-specific data (29 bits)
%
decode_node_handle(NodeAtom, decoded(Tag, TagName, Item, Frob, Flip)) :-
    % Extract hex value from atom like 'node_28006'
    atom_string(NodeAtom, Str),
    (sub_string(Str, 5, _, 0, HexStr) ->  % Skip 'node_' prefix
        atom_string(HexAtom, HexStr),
        atom_codes(HexAtom, HexCodes),
        format(atom(DecAtom), '0x~s', [HexCodes]),
        atom_number(DecAtom, Value)
    ; Value = 0),

    % Decode tag (bits 0-2)
    TagNum is Value /\ 0x7,
    tag_name(TagNum, TagName),

    % Check if it's an oper node
    (member(TagNum, [4, 5, 6]) ->  % hcat, fork, cons
        FrobWarp is (Value >> 3) /\ 0x1,
        FrobNest is (Value >> 4) /\ 0x3F,
        Frob = frob(FrobWarp, FrobNest),
        Flip is (Value >> 10) /\ 0x1,
        Item is Value >> 11,
        Tag = oper(TagNum)
    ;  % Terminal node
        Frob = none,
        Flip = none,
        Item is Value >> 3,
        Tag = terminal(TagNum)
    ).

%! tag_name(+TagNum:int, -Name:atom) is det.
%  Maps tag number to name.
tag_name(0, span).
tag_name(1, quad).
tag_name(2, trip).
tag_name(3, rune).
tag_name(4, hcat).
tag_name(5, fork).
tag_name(6, cons).

%! node_type(+NodeAtom:atom, -Type:atom) is det.
%  Gets the type of a node.
node_type(NodeAtom, Type) :-
    decode_node_handle(NodeAtom, decoded(_, Type, _, _, _)).

%! node_item(+NodeAtom:atom, -Item:int) is det.
%  Gets the item/index from a node handle.
node_item(NodeAtom, Item) :-
    decode_node_handle(NodeAtom, decoded(_, _, Item, _, _)).

%! find_node_data(+NodeAtom:atom, -Data:compound) is semidet.
%  Finds the data for a node in the heap dump.
%  Unifies Data with node facts or pair facts.
find_node_data(NodeAtom, hcat_pair(Idx, Head, Tail)) :-
    node_item(NodeAtom, Idx),
    node_type(NodeAtom, hcat),
    user:hcat_pair(Idx, Head, Tail).

find_node_data(NodeAtom, fork_pair(Idx, Head, Tail)) :-
    node_item(NodeAtom, Idx),
    node_type(NodeAtom, fork),
    user:fork_pair(Idx, Head, Tail).

find_node_data(NodeAtom, cons_pair(Idx, Head, Tail)) :-
    node_item(NodeAtom, Idx),
    node_type(NodeAtom, cons),
    user:cons_pair(Idx, Head, Tail).

find_node_data(NodeAtom, node(Type, Data)) :-
    (user:node(NodeAtom, Type, D1, D2) ->
        Data = [D1, D2]
    ; user:node(NodeAtom, Type, D1, D2, D3) ->
        Data = [D1, D2, D3]
    ; user:node(NodeAtom, Type, D1, D2, D3, D4) ->
        Data = [D1, D2, D3, D4]
    ; user:node(NodeAtom, Type, D1, D2, D3, D4, D5) ->
        Data = [D1, D2, D3, D4, D5]
    ; user:node(NodeAtom, Type, D1, D2, D3, D4, D5, D6) ->
        Data = [D1, D2, D3, D4, D5, D6]
    ; fail).

%! trace_node(+NodeAtom:atom) is det.
%  Traces a node and prints its structure.
trace_node(NodeAtom) :-
    trace_node(NodeAtom, 0).

%! trace_node(+NodeAtom:atom, +Indent:int) is det.
%  Traces a node with indentation.
trace_node(NodeAtom, Indent) :-
    trace_node_with_prefix(NodeAtom, Indent, '').

trace_node_with_prefix(NodeAtom, Indent, Prefix) :-
    decode_node_handle(NodeAtom, decoded(_, Type, Item, Frob, Flip)),

    % Draw the prefix
    write(Prefix),

    % Get human-readable content
    (find_node_data(NodeAtom, Data) ->
        render_node_content(Type, Data, ContentStr)
    ; ContentStr = '[no data]'),

    % Print the node line
    format('~w~n', [ContentStr]),

    % Recursively trace children
    (find_node_data(NodeAtom, Data) ->
        (Data = cons_pair(_, Head, Tail) ->
            NextIndent is Indent + 2,
            tab(NextIndent),
            trace_node_with_prefix(Head, NextIndent, '├─ '),
            tab(NextIndent),
            trace_node_with_prefix(Tail, NextIndent, '└─ ')
        ; Data = hcat_pair(_, Head, Tail) ->
            NextIndent is Indent + 2,
            tab(NextIndent),
            trace_node_with_prefix(Head, NextIndent, '├─ '),
            tab(NextIndent),
            trace_node_with_prefix(Tail, NextIndent, '└─ ')
        ; Data = fork_pair(_, Left, Right) ->
            NextIndent is Indent + 2,
            tab(NextIndent),
            trace_node_with_prefix(Left, NextIndent, '├─ left: '),
            tab(NextIndent),
            trace_node_with_prefix(Right, NextIndent, '└─ right: ')
        ; true)
    ; true).

%! render_node_content(+Type:atom, +Data:compound, -ContentStr:atom) is det.
%  Renders node content in a human-readable way
render_node_content(cons, cons_pair(_, _, _), '⊕ cons') :- !.
render_node_content(hcat, hcat_pair(_, _, _), '⊙ hcat') :- !.
render_node_content(fork, fork_pair(_, _, _), '⊗ fork') :- !.

render_node_content(span, node(span, [Text, _Char, _Side]), Str) :- !,
    format(atom(Str), 'span["~w"]', [Text]).

render_node_content(rune, node(rune, [Code, Reps]), Str) :- !,
    (Code =:= 32 -> Char = 'SPC'
    ; Code =:= 10 -> Char = '\\n'
    ; char_code(Char, Code)),
    (Reps =:= 1 ->
        format(atom(Str), 'rune[~w]', [Char])
    ; format(atom(Str), 'rune[~w × ~w]', [Char, Reps])).

render_node_content(quad, node(quad, [C0, C1, C2, C3]), Str) :- !,
    maplist(decode_char, [C0, C1, C2, C3], Chars),
    atomic_list_concat(Chars, QuadStr),
    format(atom(Str), 'quad[~w]', [QuadStr]).

render_node_content(trip, node(trip, [Reps, B0, B1, B2]), Str) :- !,
    maplist(decode_char, [B0, B1, B2], Chars),
    atomic_list_concat(Chars, TripStr),
    (Reps =:= 1 ->
        format(atom(Str), 'trip[~w]', [TripStr])
    ; format(atom(Str), 'trip[~w × ~w]', [TripStr, Reps])).

render_node_content(Type, Data, Str) :-
    format(atom(Str), '~w ~w', [Type, Data]).

decode_char(0, '') :- !.
decode_char(32, '_') :- !.
decode_char(10, '\\n') :- !.
decode_char(Code, Char) :-
    Code > 0, Code < 128,
    char_code(Char, Code), !.
decode_char(Code, Code).

%! blob_text(+Index:int, -Text:string) is semidet.
%  Helper to get text from blob if available
blob_text(Index, Text) :-
    user:blob_entry(Index, Text), !.
blob_text(_, '[blob]').

%! render_tree(+RootNode:atom) is det.
%  Renders the entire tree structure starting from a root node.
render_tree(Root) :-
    format('~n=== Tree Structure ===~n~n', []),
    trace_node(Root, 0),
    nl.

%! calculate_length(+NodeAtom:atom, -Length:int) is det.
%  Calculates the total character length of a node when emitted flat.
%  This recursively counts all characters in the tree.
calculate_length(NodeAtom, Length) :-
    (find_node_data(NodeAtom, Data) ->
        calculate_data_length(NodeAtom, Data, Length)
    ; Length = 0).

calculate_data_length(_, node(span, [Text, _, _]), Length) :- !,
    atom_length(Text, Length).

calculate_data_length(_, node(rune, [_Code, Reps]), Reps) :- !.

calculate_data_length(_, node(quad, [C0, C1, C2, C3]), Length) :- !,
    include(\=(0), [C0, C1, C2, C3], NonZero),
    length(NonZero, Length).

calculate_data_length(_, node(trip, [Reps, _, _, _]), Length) :- !,
    Length is Reps * 3.

calculate_data_length(_, cons_pair(_, Head, Tail), Length) :- !,
    calculate_length(Head, HeadLen),
    calculate_length(Tail, TailLen),
    Length is HeadLen + TailLen.

calculate_data_length(_, hcat_pair(_, Head, Tail), Length) :- !,
    calculate_length(Head, HeadLen),
    calculate_length(Tail, TailLen),
    Length is HeadLen + TailLen.

calculate_data_length(_, fork_pair(_, Left, _Right), Length) :- !,
    % Fork in flat mode only emits left branch
    calculate_length(Left, Length).

calculate_data_length(_, _, 0).

% Export predicates
:- multifile user:hcat_pair/3, user:cons_pair/3, user:fork_pair/3, user:node/3, user:node/4, user:node/5, user:node/6, user:node/7.
