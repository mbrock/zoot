:- consult('heap_dump.pl').

% Trace the tree from root
trace(Node, Indent) :-
    node(Node, cons, Nest, Warp, Head, Tail),
    !,
    format('~w~w cons(nest=~d, warp=~d)~n', [Indent, Node, Nest, Warp]),
    atom_concat(Indent, '  ├─', Indent1),
    atom_concat(Indent, '  └─', Indent2),
    trace(Head, Indent1),
    trace(Tail, Indent2).

trace(Node, Indent) :-
    node(Node, span, Text, _, _),
    !,
    format('~w~w span: "~s"~n', [Indent, Node, Text]).

trace(Node, Indent) :-
    node(Node, rune, Code, Reps),
    !,
    Char is Code,
    format('~w~w rune: ~c (×~d)~n', [Indent, Node, Char, Reps]).

trace(Node, Indent) :-
    node(Node, quad, Ch0, Ch1, Ch2, Ch3),
    !,
    format('~w~w quad: [~d,~d,~d,~d]~n', [Indent, Node, Ch0, Ch1, Ch2, Ch3]).

trace(Node, Indent) :-
    format('~w~w <unknown>~n', [Indent, Node]).

% Run the trace
:- writeln('=== Tree structure from root ==='),
   duel(_, RootNode, _, _, _, _, _),
   trace(RootNode, ''),
   halt.
