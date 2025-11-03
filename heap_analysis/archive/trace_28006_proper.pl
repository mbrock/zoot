:- consult('heap_019.pl').
:- style_check(-discontiguous).

% Recursively render a node to understand its structure
render_node(Node, Indent) :-
    format('~w', [Indent]),

    % Check if it's a cons
    (cons_pair(Idx, Head, Tail), Node = cons(Idx) ->
        format('cons_pair(~w):~n', [Idx]),
        IndentMore is Indent + 2,
        format('~w  head: ', [Indent]),
        render_node(Head, IndentMore),
        format('~w  tail: ', [Indent]),
        render_node(Tail, IndentMore)
    % Check if it's an hcat
    ; hcat_pair(Idx, Head, Tail), Node = hcat(Idx) ->
        format('hcat_pair(~w):~n', [Idx]),
        IndentMore is Indent + 2,
        format('~w  head: ', [Indent]),
        render_node(Head, IndentMore),
        format('~w  tail: ', [Indent]),
        render_node(Tail, IndentMore)
    % Check if it's defined as a node
    ; (node(Node, Type, Data1, Data2) ->
        format('~w(~w, ~w)~n', [Type, Data1, Data2])
    ; node(Node, Type, Data1, Data2, Data3) ->
        format('~w(~w, ~w, ~w)~n', [Type, Data1, Data2, Data3])
    ; node(Node, Type, Data1, Data2, Data3, Data4, Data5) ->
        format('~w(~w, ~w, ~w, ~w, ~w)~n', [Type, Data1, Data2, Data3, Data4, Data5])
    ; format('~w [unknown/atom]~n', [Node]))).

trace_28006 :-
    write('=== Tracing node_28006 structure ==='), nl, nl,
    write('best(0, node_28006, 23, 0, 0, 0) means:'), nl,
    write('  last=23, rows=0, overflow=0, height=0'), nl, nl,

    write('cons_pair(80, node_27806, node_3e823)'), nl, nl,

    write('So node_28006 is a cons of:'), nl,
    write('  Head: node_27806'), nl,
    write('  Tail: node_3e823'), nl, nl.

:- trace_28006.
:- halt.
