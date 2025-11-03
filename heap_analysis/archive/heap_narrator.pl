/** <module> Heap Narrator - A Documentary on the Life of Pretty Printer Heaps

This provides quasi-natural language narration of heap dump snapshots,
describing the dramatic journey of nodes through the pretty printer's evaluation.

@author The Heap Detective
@license MIT
*/

% Declare expected predicates from heap dumps as dynamic
:- dynamic pile/4, best/6, memo/4, duel/7, hcat_pair/3, fork_pair/3, cons_pair/3.
:- style_check(-discontiguous).  % Suppress discontiguous warnings

%! narrate(+File) is det.
%  Load a heap snapshot and narrate what's happening in dramatic documentary style.
narrate(File) :-
    consult(File),
    nl, write('═══════════════════════════════════════'), nl,
    write('      HEAP DOCUMENTARY'),nl,
    write('═══════════════════════════════════════'), nl, nl,
    narrate_the_scene,
    nl.

narrate_the_scene :-
    findall(_, pile(_,_,_,_), Piles), length(Piles, PileSize),
    findall(_, best(_,_,_,_,_,_), Bests), length(Bests, BestCount),
    findall(_, memo(_,_,_,_), Memos), length(Memos, MemoCount),
    findall(_, duel(_,_,_,_,_,_,_), Duels), length(Duels, DuelCount),

    opening_line(PileSize),
    memo_commentary(MemoCount),
    frontier_drama(BestCount, DuelCount),
    closing_thought(PileSize, BestCount).

opening_line(0) :-
    write('Our protagonist rests. The pile lies empty, the work complete.'), nl, !.
opening_line(1) :-
    write('A single task awaits in the pile, lonely but determined.'), nl, !.
opening_line(N) :-
    format('The pile teems with ~w tasks, each crying out for evaluation!', [N]), nl.

memo_commentary(0) :-
    write('The memo table stands barren—no memories yet formed.'), nl, !.
memo_commentary(N) :-
    N < 10,
    format('A modest memo table holds ~w precious memories.', [N]), nl, !.
memo_commentary(N) :-
    N < 50,
    format('The memo table burgeons with ~w entries—experience accumulates!', [N]), nl, !.
memo_commentary(N) :-
    format('Behold! ~w memos crowd the table, a vast library of computed wisdom.', [N]), nl.

frontier_drama(0, 0) :-
    write('No alternatives have emerged. The frontier remains undiscovered.'), nl, !.
frontier_drama(0, D) :-
    format('~w duels await in the shadows, but none have been crowned champion.', [D]), nl, !.
frontier_drama(1, _) :-
    best(_, Node, Last, _, Overflow, Height),
    format('A victor emerges! Node ~w (last=~w, overflow=~w, height=~w) stands alone.',
           [Node, Last, Overflow, Height]), nl, !.
frontier_drama(B, D) :-
    format('The Pareto frontier trembles with ~w candidates and ~w dueling alternatives!', [B, D]), nl.

closing_thought(0, B) :-
    B > 0,
    write('The journey ends. A winner has been chosen.'), nl, !.
closing_thought(P, 0) :-
    P > 0,
    write('The adventure continues—much work remains undone!'), nl, !.
closing_thought(_, _) :-
    write('In medias res: both work and results coexist in delicate balance.'), nl.

%! investigate(+File) is det.
%  Detective mode: investigate what's suspicious in this heap.
investigate(File) :-
    consult(File),
    nl,
    write('🔍 ═══════════════════════════════════════'), nl,
    write('       DETECTIVE MODE ACTIVATED'), nl,
    write('   ═══════════════════════════════════════ 🔍'), nl, nl,
    investigate_mysteries,
    nl.

investigate_mysteries :-
    investigate_orphans,
    investigate_memo_hits,
    investigate_overflow,
    investigate_pile_oddities.

investigate_orphans :-
    write('Looking for orphaned nodes...'), nl,
    findall(N, (duel(_,N,_,_,_,_,_), \+ hcat_pair(_,_,N), \+ hcat_pair(_,N,_),
                                       \+ cons_pair(_,_,N), \+ cons_pair(_,N,_),
                                       \+ fork_pair(_,_,N), \+ fork_pair(_,N,_)), Orphans),
    length(Orphans, Count),
    (Count > 0 ->
        format('  ⚠️  Found ~w orphaned duel nodes (atomic or root)~n', [Count])
    ;   write('  ✓ All duel nodes are properly connected.'), nl).

investigate_memo_hits :-
    write('Analyzing memo coverage...'), nl,
    findall(_, memo(_,_,_,_), Memos), length(Memos, MemoCount),
    findall(_, pile(_,_,_,_), Piles), length(Piles, PileSize),
    (MemoCount > PileSize, PileSize > 0 ->
        Ratio is MemoCount / PileSize,
        format('  💎 Excellent memo utilization! Ratio: ~2f memories per queued task~n', [Ratio])
    ; MemoCount =:= 0, PileSize > 0 ->
        write('  🔥 COLD START: No memos yet, virgin territory!'), nl
    ; write('  📊 Memo table seems proportional.'), nl).

investigate_overflow :-
    write('Checking for overflow incidents...'), nl,
    findall(_, (best(_,_,_,_,O,_), O > 0), Overflow),
    findall(_, best(_,_,_,_,0,_), Perfect),
    length(Overflow, OverflowCount),
    length(Perfect, PerfectCount),
    (OverflowCount > 0 ->
        format('  ⚠️  ~w result(s) with overflow detected!~n', [OverflowCount])
    ; true),
    (PerfectCount > 0 ->
        format('  ✨ ~w perfect result(s) with zero overflow!~n', [PerfectCount])
    ; true).

investigate_pile_oddities :-
    write('Scanning pile for oddities...'), nl,
    findall(Type, pile(_,Type,_,_), Types),
    sort(Types, UniqueTypes),
    (UniqueTypes = [eval] ->
        write('  📋 Pure evaluation mode—all pile entries are eval.'), nl
    ; UniqueTypes = [give] ->
        write('  🎁 Pure give mode—unusual!'), nl
    ; length(UniqueTypes, N), N > 1 ->
        format('  🎭 Mixed pile! Found ~w different execution types: ~w~n', [N, UniqueTypes])
    ; write('  ✓ Pile appears normal.'), nl).

%! tell_saga(+FilePattern) is det.
%  Narrate the entire saga across multiple snapshots.
%  Example: tell_saga('heap_00[0-3].pl')
tell_saga(Pattern) :-
    expand_file_name(Pattern, Files),
    sort(Files, Sorted),
    nl,
    write('╔════════════════════════════════════════════════════════════════╗'), nl,
    write('║        THE SAGA OF THE PRETTY PRINTER: A HEAP OPERA          ║'), nl,
    write('╚════════════════════════════════════════════════════════════════╝'), nl,
    nl,
    tell_saga_acts(Sorted, 0).

tell_saga_acts([], _) :- !.
tell_saga_acts([File|Rest], N) :-
    format('~n┌─ ACT ~w: ~w~n', [N, File]),
    write('└─────────────────────────────────────────────────'), nl,
    consult(File),
    narrate_the_scene,
    N1 is N + 1,
    tell_saga_acts(Rest, N1).
