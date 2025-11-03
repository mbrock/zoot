% Load heap dump and library
:- consult('../../.heapdumps/heap_019.pl').
:- use_module('../heap_lib.pl').

% Recursively analyze a cons chain
analyze_cons(Node, Depth) :-
    Indent is Depth * 2,
    tab(Indent),

    % Get actual length
    calculate_length(Node, ActualLen),

    % Try to find duel
    (user:duel(DuelID, Node, GistLast, _, _, _, _) ->
        format('~w: actual_len=~w, gist.last=~w', [Node, ActualLen, GistLast])
    ; format('~w: actual_len=~w, NO DUEL', [Node, ActualLen])),

    % Check if it's a cons
    (find_node_data(Node, cons_pair(Idx, Head, Tail)) ->
        calculate_length(Head, HeadLen),
        calculate_length(Tail, TailLen),
        format(' = cons(~w)~n', [Idx]),

        % Get head and tail gists
        (user:duel(_, Head, HeadGist, _, _, _, _) -> true ; HeadGist = none),
        (findall(TG, user:duel(_, Tail, TG, _, _, _, _), TailGists), TailGists \= [] -> true ; TailGists = [none]),

        tab(Indent),
        format('  ├─ head_len=~w, head_gist=~w~n', [HeadLen, HeadGist]),
        tab(Indent),
        format('  └─ tail_len=~w, tail_gists=~w~n', [TailLen, TailGists]),

        % Check pattern
        (HeadGist \= none, member(TailGist, TailGists), TailGist \= none,
         GistLast =:= TailGist ->
            (tab(Indent),
             format('  *** PATTERN: cons.gist (~w) = tail.gist (~w), ignoring head length (~w)!~n~n', [GistLast, TailGist, HeadLen]))
        ; nl),

        % Recurse
        NewDepth is Depth + 1,
        analyze_cons(Head, NewDepth),
        analyze_cons(Tail, NewDepth)
    ; nl).

main :-
    write('=== Recursive Analysis of node_27806 ==='), nl, nl,
    analyze_cons(node_27806, 0).

:- main.
:- halt.
