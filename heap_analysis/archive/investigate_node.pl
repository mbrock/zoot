% Load heap dump and investigate node_28006
:- consult('heap_019.pl').

% Find what this node is
find_node_28006 :-
    write('=== Investigating node_28006 ==='), nl, nl,

    % Check if it's in best results
    (best(_, node_28006, Last, Rows, O, H) ->
        format('Found in best: last=~w, rows=~w, overflow=~w, height=~w~n', [Last, Rows, O, H])
    ; write('Not in best results'), nl),

    % Check if it's in duels
    findall(ID, duel(ID, node_28006, _, _, _, _, _), DuelIDs),
    length(DuelIDs, NDuels),
    format('Found in ~w duel entries: ~w~n', [NDuels, DuelIDs]),

    % Check if it's in any pairs
    (hcat_pair(_, node_28006, _) ; hcat_pair(_, _, node_28006) ->
        write('Found in hcat pairs'), nl
    ; write('NOT in hcat pairs'), nl),

    (cons_pair(_, node_28006, _) ; cons_pair(_, _, node_28006) ->
        write('Found in cons pairs'), nl
    ; write('NOT in cons pairs'), nl),

    (fork_pair(_, node_28006, _) ; fork_pair(_, _, node_28006) ->
        write('Found in fork pairs'), nl
    ; write('NOT in fork pairs'), nl),

    % Check if it's defined as a node
    (node(node_28006, _, _, _) ; node(node_28006, _, _, _, _) ; node(node_28006, _, _, _, _, _) ->
        write('Found as a node definition'), nl
    ; write('NOT defined as a node'), nl),

    nl, write('=== Node appears to be ORPHANED - only in duel list! ==='), nl.

% Try to decode the node handle
decode_node_28006 :-
    nl, write('=== Decoding node_28006 handle ==='), nl,
    % node_28006 in hex
    format('node_28006 = 0x~16r~n', [16#28006]),

    % Try to understand the structure
    % Nodes are 32-bit packed structures
    Tag is 16#28006 /\ 16#7,
    ItemOrData is 16#28006 >> 3,
    format('Tag (low 3 bits): ~w~n', [Tag]),
    format('Item/Data (upper bits): 0x~16r = ~w~n', [ItemOrData, ItemOrData]),

    % Common tags (guessing based on code):
    % 0 = span, 1 = rune, 2 = quad, 3 = trip, 4 = hcat, 5 = fork, 6 = cons
    TagName = [span, rune, quad, trip, hcat, fork, cons],
    (Tag < 7 ->
        nth0(Tag, TagName, Name),
        format('Likely node type: ~w~n', [Name])
    ; write('Unknown tag'), nl).

:- find_node_28006.
:- decode_node_28006.
:- halt.
