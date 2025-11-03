% Test script for the narrator
:- consult('heap_000.pl').
:- use_module('heap_narrator.pl').

test_simple :-
    narrate_snapshot('heap_001.pl').

test_detective :-
    investigate('heap_019.pl').

test_story :-
    tell_story('heap_*.pl').

test_compare :-
    compare_snapshots('heap_000.pl', 'heap_001.pl').
