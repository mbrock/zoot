% Load heap dump and library
:- consult('../../.heapdumps/heap_019.pl').
:- use_module('../heap_lib.pl').

%! emit_node(+NodeAtom:atom) is det.
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

check :-
    cons_pair(80, Head, Tail),

    write('HEAD (node_27806):'), nl,
    write('  Emits: "'),
    emit_node(Head),
    write('"'), nl,
    calculate_length(Head, HeadLen),
    format('  Length: ~w~n', [HeadLen]),
    nl,

    write('TAIL (node_3e823):'), nl,
    write('  Emits: "'),
    emit_node(Tail),
    write('"'), nl,
    calculate_length(Tail, TailLen),
    format('  Length: ~w~n', [TailLen]),
    nl,

    write('HEAD + TAIL:'), nl,
    write('  Emits: "'),
    emit_node(Head),
    emit_node(Tail),
    write('"'), nl,
    TotalLen is HeadLen + TailLen,
    format('  Total length: ~w~n', [TotalLen]),
    nl,

    write('GIST DATA:'), nl,
    user:duel(168, Head, HeadLast, HeadRows, _, _, _),
    format('  Head duel: last=~w, rows=~w~n', [HeadLast, HeadRows]),
    user:duel(169, Tail, TailLast, TailRows, _, _, _),
    format('  Tail duel (ID=169): last=~w, rows=~w~n', [TailLast, TailRows]),
    user:best(0, node_28006, ConsLast, ConsRows, _, _),
    format('  Cons best: last=~w, rows=~w~n', [ConsLast, ConsRows]),
    nl,

    write('PROBLEM:'), nl,
    format('  Head actually emits ~w chars but gist says last=~w~n', [HeadLen, HeadLast]),
    format('  Tail actually emits ~w chars but gist says last=~w~n', [TailLen, TailLast]),
    format('  Cons actually emits ~w chars but gist says last=~w~n', [TotalLen, ConsLast]).

:- check.
:- halt.
