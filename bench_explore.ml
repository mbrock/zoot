(* Exploration benchmark matching the Zig version *)

module P = Pretty_expressive.Printer.Make(
  val Pretty_expressive.Printer.default_cost_factory ~page_width:80 ()
)

open P

let time_ns f =
  let start = Unix.gettimeofday () in
  let result = f () in
  let finish = Unix.gettimeofday () in
  let time_ns = Int64.of_float ((finish -. start) *. 1e9) in
  (result, time_ns)

let bench_suite name width n builder =
  let (output, total_time) = time_ns (fun () ->
    let doc = builder n in
    pretty_format doc
  ) in
  Printf.printf "%-20s n=%4d w=%3d | total:%6Ldµs | size:%5d\n"
    name n width (Int64.div total_time 1000L) (String.length output)

(* Simple concat chain *)
let build_concat_chain n =
  let rec loop i doc =
    if i >= n then doc
    else loop (i + 1) (doc ^^ text " X")
  in
  loop 0 (text "start")

(* Binary tree S-expression *)
let rec build_sexp_tree depth =
  if depth = 0 then
    text "leaf"
  else
    let left = build_sexp_tree (depth - 1) in
    let right = build_sexp_tree (depth - 1) in
    lparen ^^ text "node" ^^ space ^^ left ^^ space ^^ right ^^ rparen

(* Many choices: tests fork performance *)
let build_many_choices n =
  let rec loop i doc =
    if i >= n then doc
    else
      let inline_opt = space ^^ text "item" in
      let multiline_opt = nl ^^ text "item" in
      let choice = inline_opt <|> multiline_opt in
      loop (i + 1) (doc ^^ choice)
  in
  loop 0 (text "start")

(* Grouped (simulate group combinator) *)
let build_grouped n =
  let rec loop i doc =
    if i >= n then doc ^^ rparen
    else
      let prefix = if i = 0 then empty else comma in
      let item_flat = space ^^ text "arg" in
      let item_break = nl ^^ nest 2 (text "arg") in
      let grouped = item_flat <|> item_break in
      loop (i + 1) (doc ^^ prefix ^^ grouped)
  in
  loop 0 (text "func" ^^ lparen)

(* Nested blocks *)
let rec build_nested depth =
  if depth = 0 then
    text "x"
  else
    let inner = build_nested (depth - 1) in
    lbrace ^^ nl ^^ nest 2 inner ^^ nl ^^ rbrace

let () =
  print_endline "\nPretty Printer Exploration Benchmark (OCaml)";
  print_endline "=============================================\n";

  print_endline "--- Width sensitivity (Concat Chain) ---";
  bench_suite "Concat" 40 50 build_concat_chain;
  bench_suite "Concat" 80 50 build_concat_chain;
  bench_suite "Concat" 120 50 build_concat_chain;
  print_endline "";

  print_endline "--- Many Choices (fork-heavy) ---";
  bench_suite "Choices" 80 3 build_many_choices;
  bench_suite "Choices" 80 5 build_many_choices;
  bench_suite "Choices" 80 7 build_many_choices;
  bench_suite "Choices" 80 10 build_many_choices;
  bench_suite "Choices" 80 12 build_many_choices;
  bench_suite "Choices" 80 14 build_many_choices;
  bench_suite "Choices" 80 22 build_many_choices;
  print_endline "";

  print_endline "--- S-Exp Tree (exponential nodes) ---";
  bench_suite "Tree" 80 3 build_sexp_tree;
  bench_suite "Tree" 80 4 build_sexp_tree;
  bench_suite "Tree" 80 5 build_sexp_tree;
  bench_suite "Tree" 80 6 build_sexp_tree;
  print_endline "";

  print_endline "--- Grouped args (like group combinator) ---";
  bench_suite "Grouped" 80 3 build_grouped;
  bench_suite "Grouped" 80 5 build_grouped;
  bench_suite "Grouped" 80 7 build_grouped;
  bench_suite "Grouped" 80 10 build_grouped;
  print_endline "";

  print_endline "--- Nested blocks ---";
  bench_suite "Nested" 80 5 build_nested;
  bench_suite "Nested" 80 7 build_nested;
  bench_suite "Nested" 80 10 build_nested;
  print_endline ""
