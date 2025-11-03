% Load heap dump and library
:- consult('../../.heapdumps/heap_019.pl').
:- use_module('../heap_lib.pl').

% Collect all cons nodes in a tree and their actual lengths
collect_cons_nodes(Node, Pairs) :-
    collect_cons_nodes_helper(Node, [], PairsRev),
    reverse(PairsRev, Pairs).

collect_cons_nodes_helper(Node, Acc, Result) :-
    (find_node_data(Node, cons_pair(_, Head, Tail)) ->
        calculate_length(Node, Len),
        NewAcc = [Node-Len | Acc],
        collect_cons_nodes_helper(Head, NewAcc, Acc1),
        collect_cons_nodes_helper(Tail, Acc1, Result)
    ; Result = Acc).

% Find all subsets that sum to Target
find_subset_sum(List, Target, Subset) :-
    append(_, [Item|Rest], List),
    Item = _-Value,
    (Value = Target ->
        Subset = [Item]
    ; Value < Target,
      NewTarget is Target - Value,
      find_subset_sum(Rest, NewTarget, SubRest),
      Subset = [Item | SubRest]).

% Analyze the head node
analyze :-
    write('=== Analyzing node_27806 (the head) ==='), nl, nl,

    % Get gist from duel
    user:duel(168, node_27806, GistLast, _, _, _, _),
    format('Gist says last=~w~n', [GistLast]),

    % Get actual length
    calculate_length(node_27806, ActualLen),
    format('Actually emits ~w characters~n~n', [ActualLen]),

    % Get all cons nodes in tree
    cons_pair(79, Head79, Tail79),
    format('node_27806 = cons_pair(79, ~w, ~w)~n~n', [Head79, Tail79]),

    % Calculate lengths for head and tail
    calculate_length(Head79, HeadLen),
    calculate_length(Tail79, TailLen),
    format('  Head: ~w emits ~w chars~n', [Head79, HeadLen]),
    format('  Tail: ~w emits ~w chars~n~n', [Tail79, TailLen]),

    % Check if gist matches head length
    (HeadLen = GistLast ->
        write('PATTERN: gist.last = head.length!'), nl, nl
    ; format('Head length (~w) != gist (~w)~n~n', [HeadLen, GistLast])),

    % Get gists for head and tail
    (user:duel(_, Head79, HeadGist, _, _, _, _) ->
        format('  Head gist: last=~w~n', [HeadGist])
    ; write('  Head has no duel~n')),

    (user:duel(_, Tail79, TailGist, _, _, _, _) ->
        format('  Tail gist: last=~w~n~n', [TailGist])
    ; write('  Tail has no duel~n~n')),

    % Try to find patterns - does gist = head's gist?
    (HeadGist = GistLast ->
        write('PATTERN FOUND: cons.gist.last = head.gist.last'), nl,
        write('This suggests cons is NOT adding tail offset!'), nl
    ; true).

:- analyze.
:- halt.
