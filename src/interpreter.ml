
(* The lexer generator. Command-line parsing. *)

let opt_infile = ref None
let opt_parse_intf = ref false
let opt_stack_items = ref false
let opt_dump_states = ref false
let opt_no_reduce_filter = ref false

let usage =
  Printf.sprintf
    "Parser interpreter\n\
     Prints detailed information to help working out error patterns.\n\
     \n\
     Usage: %s [-intf] [-no-items] [-no-reductions] [-all-items] <-|foo.ml|bar.mli>"
    Sys.argv.(0)

let print_version_num () =
  print_endline "0.1";
  exit 0

let print_version_string () =
  print_string "The Menhir parser lexer generator :-], version ";
  print_version_num ()

let specs = [
  "-", Arg.Unit (fun () -> opt_infile := Some "-"),
  " Read input from stdin";
  "-intf", Arg.Set opt_parse_intf,
  " Parse an interface (by default: use extension or parse an implementation)";
  "-no-reduce-filter", Arg.Set opt_no_reduce_filter,
  " Do not print reachable reduce-filter patterns";
  "-stack-items", Arg.Set opt_stack_items,
  " Print items of all states on stack";
  "-v",  Arg.Unit print_version_string,
  " Print version and exit";
  "-version",  Arg.Unit print_version_string,
  " Print version and exit";
  "-vnum",  Arg.Unit print_version_num,
  " Print version number and exit";
  "-dump-states", Arg.Set opt_dump_states,
  " Print state numbers for debugging purpose";
]

let () = Arg.parse specs (fun name -> opt_infile := Some name) usage

let grammar_filename =
  let filename, oc = Filename.open_temp_file "lrgrep-interpreter" "cmly" in
  output_string oc Interpreter_data.grammar;
  close_out oc;
  filename

module Grammar = MenhirSdk.Cmly_read.Read(struct let filename = grammar_filename end)
module Interpreter = Lrgrep_interpreter.Make(Grammar)()

let () = Sys.remove grammar_filename

let get_token lexbuf =
  match Lexer_raw.token lexbuf with
  | exception Lexer_raw.Error (err, loc) ->
    Format.eprintf "%a\n%!"
      Location.print_report (Lexer_raw.prepare_error loc err);
    exit 1
  | tok -> tok

let do_parse
    (type a)
    (checkpoint : Lexing.position -> a Parser_raw.MenhirInterpreter.checkpoint)
    lexbuf
  =
  let module I = Parser_raw.MenhirInterpreter in
  let rec loop : _ I.env -> _ I.checkpoint -> _ = fun env -> function
    | I.Shifting (_, _, _) | I.AboutToReduce (_, _) as cp ->
      loop env (I.resume cp)
    | I.Accepted _ -> None
    | I.Rejected -> assert false
    | I.HandlingError _ ->
      Some env
    | I.InputNeeded env' as cp ->
      match get_token lexbuf with
      | Parser_raw.EOF -> Some env'
      | token ->
        loop env' (I.offer cp (token, lexbuf.lex_start_p, lexbuf.lex_curr_p))
  in
  match checkpoint lexbuf.lex_curr_p with
  | I.InputNeeded env as cp -> loop env cp
  | _ -> assert false


let rec get_states initial_loc env () =
  let module I = Parser_raw.MenhirInterpreter in
  let state = Grammar.Lr1.of_int (I.current_state_number env) in
  let start, stop =
    match I.top env with
    | Some (I.Element (_,_,start,stop)) -> (start, stop)
    | None -> (initial_loc, initial_loc)
  in
  Seq.Cons (
    (state, start, stop),
    match I.pop env with
    | None -> Seq.empty
    | Some env' -> get_states initial_loc env'
  )

let process_result (lexbuf : Lexing.lexbuf) = function
  | None -> print_endline "Successful parse"
  | Some env ->
    let initial_loc = {
      Lexing.
      pos_fname = lexbuf.lex_start_p.pos_fname;
      pos_lnum = 1;
      pos_bol = 0;
      pos_cnum = 0;
    } in
    let config = {
      Lrgrep_interpreter.default_config with
      print_reduce_filter = not !opt_no_reduce_filter;
      print_stack_items = !opt_stack_items;
    } [@ocaml.warning "w-23"] in
    let stack = get_states initial_loc env in
    Interpreter.analyze_stack config stack;
    if !opt_dump_states then
      Printf.printf "states = %s\n"
        (String.concat ","
           (List.map (fun (idx, _, _) -> string_of_int (Grammar.Lr1.to_int idx))
              (List.of_seq stack)))

let () =
  match !opt_infile with
  | None | Some "" ->
    Format.eprintf "No input provided, stopping now.\n";
    Arg.usage specs usage;
  | Some file ->
    let is_intf = !opt_parse_intf || Filename.check_suffix file "i" in
    let ic, filename, close_ic =
      if file = "-" then
        (stdin, "<stdin>", false)
      else
        (open_in_bin file, file, true)
    in
    let lexbuf =
      let lexbuf = Lexing.from_channel ~with_positions:true ic in
      Lexing.set_filename lexbuf filename;
      lexbuf
    in
    if is_intf then
      process_result lexbuf
        (do_parse Parser_raw.Incremental.interface lexbuf)
    else
      process_result lexbuf
        (do_parse Parser_raw.Incremental.implementation lexbuf);
    if close_ic then
      close_in_noerr ic
