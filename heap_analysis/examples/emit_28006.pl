% Load heap dump and library
:- consult('../../.heapdumps/heap_019.pl').
:- use_module('../heap_lib.pl').

%! emit_node(+NodeAtom:atom) is det.
%  Emits the characters from a node tree
emit_node(NodeAtom) :-
    (find_node_data(NodeAtom, Data) ->
        emit_data(Data)
    ; true).

emit_data(node(span, [Text, _, _])) :- !,
    write(Text).

emit_data(node(rune, [Code, Reps])) :- !,
    char_code(Char, Code),
    forall(between(1, Reps, _), write(Char)).

emit_data(node(quad, [C0, C1, C2, C3])) :- !,
    forall(member(C, [C0, C1, C2, C3]),
           (C > 0 -> char_code(Ch, C), write(Ch) ; true)).

emit_data(node(trip, [Reps, B0, B1, B2])) :- !,
    forall(between(1, Reps, _),
           forall(member(B, [B0, B1, B2]),
                  (B > 0 -> char_code(Ch, B), write(Ch) ; true))).

emit_data(cons_pair(_, Head, Tail)) :- !,
    emit_node(Head),
    emit_node(Tail).

emit_data(hcat_pair(_, Head, Tail)) :- !,
    emit_node(Head),
    emit_node(Tail).

emit_data(fork_pair(_, Left, _Right)) :- !,
    emit_node(Left).

test_emit :-
    write('Emitted text: "'),
    emit_node(node_28006),
    write('"'), nl,

    % Calculate and measure
    calculate_length(node_28006, CalcLen),
    format('Calculated length: ~w~n', [CalcLen]),

    % Compare with gist
    user:best(0, node_28006, Last, _, _, _),
    format('Gist last: ~w~n', [Last]),
    format('Discrepancy: ~w~n', [CalcLen - Last]).

:- test_emit.
:- halt.
