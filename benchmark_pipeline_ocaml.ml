(* OCaml counterpart of src/main.zig's dump.dump benchmark.  It deliberately
   reproduces src/dump.zig's container shape: a vertical .{ ... } document
   chosen against its flattened form.

   Reproduce from the repository root with:
     opam switch create . ocaml-system
     opam install dune alcotest
     eval $(opam env)
     dune build ocaml-reference/test/main.exe benchmark_pipeline_ocaml.exe
     dune exec ./benchmark_pipeline_ocaml.exe -- 100

   Cost is F2 (sum of squared line overflows, then newline count) at width 60.
   Upstream OCaml also exposes a separate computation-width taint bound, whose
   default is 1.2 * page width.  Zig F2 has no corresponding configurable
   bound and reports "tainted" when the selected rank has nonzero overflow.
   This input has zero overflow, so that API mismatch does not affect rank. *)

module Cost = struct
  type t = int * int * int
  let page_width = 60
  let limit = 72 (* upstream default: int_of_float (1.2 * page_width) *)
  let text pos len =
    let stop = pos + len in
    if stop > page_width then
      let maxwc = max page_width pos in
      let a = maxwc - page_width in
      let b = stop - maxwc in
      (b * ((2 * a) + b), 0, 0)
    else (0, 0, 0)
  let newline _ = (0, 0, 1)
  let combine (o1, s1, h1) (o2, s2, h2) = (o1 + o2, s1 + s2, h1 + h2)
  let le a b = a <= b
  let two_columns_overflow w = (0, w, 0)
  let two_columns_bias _ = (0, 0, 0)
  let string_of_cost (o, s, h) = Printf.sprintf "(%d,%d,%d)" o s h
  let debug_format content tainted cost =
    Printf.sprintf "%s\ntainted=%b cost=%s" content tainted cost
end

module P = Pretty_expressive.Printer.Make (Cost)
open P

let pile = function [] -> empty | d :: ds -> List.fold_left (fun a b -> a ^^ nl ^^ b) d ds

let container items =
  match items with
  | [] -> text ".{}"
  | _ ->
    let body = pile (List.map (fun d -> d ^^ text ",") items) in
    let block = pile [nest 2 (pile [text ".{"; body]); text "}"] in
    block <|> flatten block

let quoted s = text (Printf.sprintf "%S" s)
let field name value = text ("." ^ name ^ " = ") ^^ value
let struct_ fields = container (List.map (fun (name, value) -> field name value) fields)
let array values = container values

let run_doc tool args = struct_ ["tool", quoted tool; "args", array (List.map quoted args)]
let run tool args = container [field "run" (run_doc tool args)]
let wait seconds = container [field "wait" (text (string_of_int seconds))]
let parallel steps = container [field "parallel" (array steps)]

let pipeline i =
  let build_args = List.init 4 (fun _ -> ["build"; "-Drelease-safe=true"]) |> List.flatten in
  let steps = [
    run "zig" build_args;
    wait 30;
    parallel [run "zig" ["test"]; run "deploy" ["us-west"; "blue"]]
  ] in
  struct_ [
    "name", quoted (Printf.sprintf "pipeline-%d" i);
    "enabled", text (if i mod 2 = 0 then "true" else "false");
    "retries", text (if i mod 5 = 0 then "null" else string_of_int (i mod 5));
    "tags", array (List.map quoted ["cli"; "zig"; "pretty"]);
    "steps", array steps;
  ]

let now () = Unix.gettimeofday ()

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 100 in
  let emit = Array.length Sys.argv > 2 && Sys.argv.(2) = "--emit" in
  let t0 = now () in
  let doc = array (List.init n pipeline) in
  let t1 = now () in
  let output, info = pretty_format_info doc in
  let t2 = now () in
  let overflow, separator, height = info.cost in
  Printf.printf
    "n=%d width=%d computation_width=%d build_ms=%.3f resolve_emit_ms=%.3f bytes=%d lines=%d rank=(%d,%d,%d) tainted=%b digest=%s\n%!"
    n Cost.page_width Cost.limit ((t1 -. t0) *. 1000.) ((t2 -. t1) *. 1000.)
    (String.length output) (height + 1) overflow separator height info.is_tainted
    (Digest.to_hex (Digest.string output));
  if emit then print_string output
