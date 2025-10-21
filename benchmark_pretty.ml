(* Benchmarks for Pretty_expressive OCaml library *)

module P = Pretty_expressive.Printer.Make(
  val Pretty_expressive.Printer.default_cost_factory ~page_width:80 ()
)

open P

type bench_result = {
  name : string;
  total_time_ns : int64;
  doc_size : int; (* approximate indicator *)
}

let time_ns f =
  let start = Unix.gettimeofday () in
  let result = f () in
  let finish = Unix.gettimeofday () in
  let time_ns = Int64.of_float ((finish -. start) *. 1e9) in
  (result, time_ns)

let print_result result =
  Printf.printf "\n=== %s ===\n" result.name;
  Printf.printf "  Total time: %Ld µs\n" (Int64.div result.total_time_ns 1000L);
  Printf.printf "  Doc size indicator: %d\n" result.doc_size

(* Benchmark 1: Deep concatenation chain *)
let bench_concat_chain n =
  let (output, time_ns) = time_ns (fun () ->
    let rec build_chain i doc =
      if i >= n then doc
      else build_chain (i + 1) (doc ^^ text "B")
    in
    let doc = build_chain 1 (text "A") in
    pretty_format doc
  ) in
  {
    name = "Concat Chain";
    total_time_ns = time_ns;
    doc_size = String.length output;
  }

(* Benchmark 2: Binary tree S-expression *)
let rec build_sexp_tree depth =
  if depth = 0 then
    text "leaf"
  else
    let left = build_sexp_tree (depth - 1) in
    let right = build_sexp_tree (depth - 1) in
    lparen ^^ text "node" ^^ space ^^ left ^^ space ^^ right ^^ rparen

let bench_sexp_tree depth =
  let (output, time_ns) = time_ns (fun () ->
    let doc = build_sexp_tree depth in
    pretty_format doc
  ) in
  {
    name = "S-Exp Tree";
    total_time_ns = time_ns;
    doc_size = String.length output;
  }

(* Benchmark 3: Many choices *)
let bench_many_choices n =
  let (output, time_ns) = time_ns (fun () ->
    let rec build_choices i doc =
      if i >= n then doc
      else
        let inline_opt = space ^^ text "item" ^^ text (string_of_int i) in
        let multiline_opt = nl ^^ text "item" ^^ text (string_of_int i) in
        let choice = inline_opt <|> multiline_opt in
        build_choices (i + 1) (doc ^^ choice)
    in
    let doc = build_choices 0 (text "start") in
    pretty_format doc
  ) in
  {
    name = "Many Choices";
    total_time_ns = time_ns;
    doc_size = String.length output;
  }

(* Benchmark 4: Nested indentation *)
let rec build_nested_indent depth =
  if depth = 0 then
    text "body"
  else
    let inner = build_nested_indent (depth - 1) in
    lbrace ^^ nl ^^ nest 2 inner ^^ nl ^^ rbrace

let bench_nested_indent depth =
  let (output, time_ns) = time_ns (fun () ->
    let doc = build_nested_indent depth in
    pretty_format doc
  ) in
  {
    name = "Nested Indent";
    total_time_ns = time_ns;
    doc_size = String.length output;
  }

(* Benchmark 5: JSON-like structure *)
let bench_json n_fields =
  let (output, time_ns) = time_ns (fun () ->
    let rec build_fields i doc =
      if i >= n_fields then doc
      else
        let key = Printf.sprintf "field%d" i in
        let value = Printf.sprintf "value%d" i in
        let field = text "  " ^^ dquote ^^ text key ^^ text "\": \"" ^^
                    text value ^^ dquote in
        let field = if i < n_fields - 1 then field ^^ comma else field in
        let field = field ^^ nl in
        build_fields (i + 1) (doc ^^ field)
    in
    let doc = lbrace ^^ nl ^^ build_fields 0 empty ^^ rbrace in
    pretty_format doc
  ) in
  {
    name = "JSON Object";
    total_time_ns = time_ns;
    doc_size = String.length output;
  }

let () =
  print_endline "Pretty Printer Benchmarks (OCaml)";
  print_endline "==================================";
  print_endline "";

  (* Run benchmarks with same parameters as Zig *)
  let r1 = bench_concat_chain 50 in
  print_result r1;

  let r2 = bench_sexp_tree 5 in
  print_result r2;

  let r3 = bench_many_choices 10 in
  print_result r3;

  let r4 = bench_nested_indent 5 in
  print_result r4;

  let r5 = bench_json 20 in
  print_result r5;

  print_endline "";
  print_endline "All benchmarks completed!"
