:- consult('heap_019.pl').

% Trace what a cons node would emit if it existed
trace_cons_20480 :-
    write('=== Attempting to trace cons_pair(20480, ...) ==='), nl,
    write('ERROR: cons_pair(20480, ...) does not exist!'), nl,
    write('Total cons pairs: '),
    findall(_, cons_pair(_, _, _), Pairs),
    length(Pairs, N),
    format('~w~n~n', [N]),

    write('Highest cons_pair index: '),
    findall(I, cons_pair(I, _, _), Indices),
    max_list(Indices, MaxIdx),
    format('~w~n~n', [MaxIdx]),

    write('This means node_28006 is INVALID - pointing to non-existent memory!'), nl, nl.

% Let's look at the highest valid cons_pair
examine_top_cons :-
    write('=== Examining highest cons_pairs ==='), nl,
    findall(I-H-T, cons_pair(I, H, T), Pairs),
    sort(Pairs, Sorted),
    reverse(Sorted, [Top1, Top2, Top3, Top4, Top5|_]),

    write('Top 5 cons_pairs:'), nl,
    forall(member(I-H-T, [Top1, Top2, Top3, Top4, Top5]),
           format('  cons_pair(~w, node_~16r, node_~16r)~n', [I, H, T])),
    nl.

% Let's see what a proper cons node looks like
examine_valid_cons_nodes :-
    write('=== Examining valid cons nodes in duels ==='), nl,

    % Find cons nodes in duels
    findall(N-Last-O, (duel(_, N, Last, _, O, _, _),
                       N /\ 7 =:= 6,  % tag = 6 (cons)
                       Idx is N >> 3,
                       Idx < 81),     % valid index
            ValidCons),

    length(ValidCons, NValid),
    format('Found ~w valid cons nodes in duels~n', [NValid]),

    % Find invalid cons nodes
    findall(N-Idx, (duel(_, N, _, _, _, _, _),
                    N /\ 7 =:= 6,
                    Idx is N >> 3,
                    Idx >= 81),
            InvalidCons),

    length(InvalidCons, NInvalid),
    format('Found ~w INVALID cons nodes in duels~n', [NInvalid]),

    (NInvalid > 0 ->
        (write('Invalid cons nodes:'), nl,
         forall(member(N-Idx, InvalidCons),
                format('  node_~16r points to cons_pair(~w) - OUT OF BOUNDS!~n', [N, Idx])))
    ; true),
    nl.

:- trace_cons_20480.
:- examine_top_cons.
:- examine_valid_cons_nodes.
:- halt.
