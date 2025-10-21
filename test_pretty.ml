(* Use the default printer with page width 80 *)
module P = Pretty_expressive.Printer.Make(
  val Pretty_expressive.Printer.default_cost_factory ~page_width:80 ()
)

open P

let () =
  print_endline "=== Testing Pretty_expressive OCaml Library ===";
  print_endline "";

  (* Example 1: Simple text *)
  print_endline "Example 1: Simple text";
  print_endline (pretty_format (text "Hello, world!"));
  print_endline "";

  (* Example 2: Concatenation with ^^ (unaligned concat) *)
  let doc2 = text "foo" ^^ space ^^ text "bar" in
  print_endline "Example 2: Concatenation";
  print_endline (pretty_format doc2);
  print_endline "";

  (* Example 3: Choice between layouts (like fork in your impl) *)
  let inline = text "foo" ^^ space ^^ text "bar" in
  let multiline = text "foo" <$> text "bar" in  (* <$> is hard newline concat *)
  let doc3 = inline <|> multiline in  (* <|> is choice *)

  print_endline "Example 3: Choice operator (picks best layout)";
  print_endline (pretty_format doc3);
  print_endline "";

  (* Example 4: Nesting (indentation) *)
  let doc4 =
    text "foo {" ^^
    nest 4 (nl ^^ text "bar") ^^
    nl ^^ text "}"
  in
  print_endline "Example 4: Nesting with indentation";
  print_endline (pretty_format doc4);
  print_endline "";

  (* Example 5: Align combinator (like warp in your impl) *)
  let doc5 =
    text "AAA" ^^
    align (text "X" <$> text "Y")
  in
  print_endline "Example 5: Align (aligns to current column)";
  print_endline (pretty_format doc5);
  print_endline "";

  (* Example 6: Group - tries flat first, falls back to multiline *)
  let doc6 = group (text "foo" ^^ nl ^^ text "bar") in
  print_endline "Example 6: Group (flattens if it fits)";
  print_endline (pretty_format doc6);
  print_endline "";

  (* Example 7: List with separators *)
  let doc7 = hcat [text "a"; comma; space; text "b"; comma; space; text "c"] in
  print_endline "Example 7: List formatting";
  print_endline (pretty_format doc7);
  print_endline "";

  (* Example 8: Nested structure like in the paper *)
  let args = text "pretty" ^^ comma ^^ nl ^^ text "print" in
  let doc8 =
    text "   = func" ^^ lparen ^^
    nest 2 args ^^
    nl ^^ rparen
  in
  print_endline "Example 8: From the paper (nested function args)";
  print_endline (pretty_format doc8)
