#!/usr/bin/env swipl
% Quick start example for heap analysis
%
% Usage: swipl quickstart.pl
%
% This demonstrates the basic workflow for investigating heap dumps.

:- consult('../.heapdumps/heap_019.pl').
:- use_module('heap_lib.pl').

quickstart :-
    write('=== Heap Analysis Quick Start ==='), nl, nl,

    % 1. Find the winning node
    write('1. Finding the best node from the heap...'), nl,
    user:best(0, WinnerNode, Last, Rows, Overflow, Height),
    format('   Winner: ~w with last=~w, rows=~w, overflow=~w, height=~w~n~n',
           [WinnerNode, Last, Rows, Overflow, Height]),

    % 2. Decode the node handle
    write('2. Decoding the node handle...'), nl,
    decode_node_handle(WinnerNode, Decoded),
    format('   ~w~n~n', [Decoded]),

    % 3. Calculate actual length
    write('3. Calculating actual character length...'), nl,
    calculate_length(WinnerNode, ActualLen),
    format('   Actual length: ~w characters~n', [ActualLen]),
    format('   Gist claims: last=~w~n', [Last]),
    Discrepancy is ActualLen - Last,
    format('   Discrepancy: ~w characters!~n~n', [Discrepancy]),

    % 4. Show tree structure (limited depth)
    write('4. Tree structure (top level):'), nl,
    render_tree(WinnerNode),
    nl,

    % 5. Investigate the structure
    write('5. Investigating cons structure...'), nl,
    (find_node_data(WinnerNode, cons_pair(Idx, Head, Tail)) ->
        format('   This is cons_pair(~w)~n', [Idx]),
        format('   Head: ~w~n', [Head]),
        format('   Tail: ~w~n~n', [Tail]),

        % Check head and tail lengths
        calculate_length(Head, HeadLen),
        calculate_length(Tail, TailLen),
        format('   Head length: ~w~n', [HeadLen]),
        format('   Tail length: ~w~n~n', [TailLen]),

        % Check their gists
        (user:duel(_, Head, HeadGist, _, _, _, _) ->
            format('   Head gist: last=~w~n', [HeadGist]),
            (HeadLen =\= HeadGist ->
                format('   ⚠ HEAD BUG: emits ~w chars but gist says ~w!~n', [HeadLen, HeadGist])
            ; true)
        ; write('   Head has no duel~n')),

        (findall(TG, user:duel(_, Tail, TG, _, _, _, _), TailGists), TailGists \= [] ->
            format('   Tail gists: ~w~n', [TailGists]),
            (member(Last, TailGists) ->
                write('   ✓ Cons uses one of tail\'s gists~n')
            ; write('   ⚠ Cons gist doesn\'t match any tail gist!~n'))
        ; write('   Tail has no duels~n'))
    ; write('   Not a cons node~n')),

    nl,
    write('6. Next steps:'), nl,
    write('   - Use render_tree/1 to see full structure'), nl,
    write('   - Query user:duel/7 to see all evaluations'), nl,
    write('   - Use findall/3 to find patterns'), nl,
    write('   - Check examples/ for more analysis techniques'), nl,
    nl.

:- quickstart.
:- halt.
