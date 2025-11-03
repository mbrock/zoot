% Load heap dump and library
:- consult('../../.heapdumps/heap_019.pl').
:- use_module('../heap_lib.pl').

analyze_winner :-
    write('=== Analyzing Winner: node_28006 ==='), nl, nl,

    write('From best/6 fact:'), nl,
    user:best(0, node_28006, Last, Rows, Overflow, Height),
    format('  last=~w, rows=~w, overflow=~w, height=~w~n~n', [Last, Rows, Overflow, Height]),

    write('Decoding node handle:'), nl,
    decode_node_handle(node_28006, Decoded),
    format('  ~w~n~n', [Decoded]),

    write('Calculating actual character length:'), nl,
    calculate_length(node_28006, ActualLength),
    format('  Actual character count: ~w~n', [ActualLength]),
    format('  Gist claims last=~w~n', [Last]),
    format('  DISCREPANCY: ~w characters difference!~n~n', [ActualLength - Last]),

    write('Full tree structure:'), nl,
    render_tree(node_28006).

:- analyze_winner.
:- halt.
