open Ocaml_parser

let usage =
  "Usage: ocaml-lrgrep-pp <file>\n\
   -----------------------------\n\n\
   ocaml-lrgrep-pp is an alternative frontend for OCaml.\n\
   It is used to prototype better syntax error messages.\n\
   \n\
   To use it, pass `-pp ocaml-lrgrep-pp` to ocaml compilers.\n\
   Alternatively, you can set the environment variable:
     OCAMLPARAM=pp=ocaml-lrgrep-pp,_
   \n\
   Usage for tests: ocaml-lrgrep --test <file1> <file2...>\n\
   -------------------------------------------------------\n\n\
   In this mode, ocaml-lrgrep will parse each file in order.\n\
   Errors are reported on stdout and the AST is discarded.\n\
   Output for each file is separated by lines starting with \"---\".
   "

exception Abort_parsing

let () = Lexer.init ()

let oprintf oc fmt =
  Format.fprintf (Format.formatter_of_out_channel oc) fmt

let error_and_exit oc lexbuf msg =
  oprintf oc "%a%!" Location.print_report {
    Location.
    kind = Location.Report_error;
    main = Location.msg ~loc:(Location.curr lexbuf) "%s" msg;
    sub = [];
    footnote = None;
  };
  raise Abort_parsing

let get_token oc lexbuf =
  match Lexer.token lexbuf with
  | exception Lexer.Error (err, loc) ->
    oprintf oc "%a\n%!" Location.print_report
      (Lexer.prepare_error loc err);
    raise Abort_parsing
  | tok ->
    (tok, lexbuf.Lexing.lex_start_p, lexbuf.Lexing.lex_curr_p)

let parse
    (type a)
    oc
    (checkpoint : Lexing.position -> a Parser.MenhirInterpreter.checkpoint)
    (lexbuf : Lexing.lexbuf)
    : a
  =
  Location.input_name := lexbuf.lex_start_p.pos_fname;
  let module I = Parser.MenhirInterpreter in
  let rec loop : a I.env -> _ -> a I.checkpoint -> _ = fun env tok -> function
    | I.InputNeeded env' as cp ->
      let tok' = get_token oc lexbuf in
      loop env' tok' (I.offer cp tok')
    | I.Shifting (_, _, _) | I.AboutToReduce (_, _) as cp ->
      begin match I.resume cp with
      | cp' -> loop env tok cp'
      | exception (Syntaxerr.Error _ as exn) ->
        match Location.error_of_exn exn with
        | Some (`Ok err) ->
          Format.eprintf "@[%a@]@."
            Location.print_report err;
          exit 1
        | _ -> assert false
      end
    | I.Accepted x -> x
    | I.Rejected -> assert false
    | I.HandlingError _ ->
       let message =
         Option.value (Errors.error_messages env tok)
           ~default:"Syntax error (no handler for it)"
       in
       error_and_exit oc lexbuf message
  in
  match checkpoint lexbuf.lex_curr_p with
  | I.InputNeeded env as cp ->
    let tok = get_token oc lexbuf in
    loop env tok (I.offer cp tok)
  | _ -> assert false

let pp_output kind ast =
  Pparse.write_ast kind "/dev/fd/1" ast

let open_input path =
  let ic = open_in path in
  let lexbuf = Lexing.from_channel ~with_positions:true ic in
  Lexing.set_filename lexbuf path;
  let is_interface = Filename.check_suffix path "i" in
  ic, lexbuf, is_interface

let pp_parse kind entrypoint lexbuf =
  pp_output kind (parse stderr entrypoint lexbuf)

let pp_main path =
  let ic, lexbuf, is_interface = open_input path in
  match
    if is_interface then
      pp_parse Pparse.Signature Parser.Incremental.interface lexbuf
    else
      pp_parse Pparse.Structure Parser.Incremental.implementation lexbuf
  with
  | () -> close_in ic
  | exception Abort_parsing ->
    close_in ic;
    exit 1

let test_main path =
  Printf.printf "--- PARSING %s\n" path;
  let ic, lexbuf, is_interface = open_input path in
  try
    if is_interface then
      ignore (parse stdout Parser.Incremental.interface lexbuf)
    else
      ignore (parse stdout Parser.Incremental.implementation lexbuf);
    close_in ic;
    Printf.printf "--- OK %s\n" path;
  with Abort_parsing ->
    close_in ic;
    Printf.printf "--- KO %s\n" path

let main () =
  let len = Array.length Sys.argv in
  if len = 2 then
    pp_main Sys.argv.(1)
  else if len >= 2 && Sys.argv.(1) = "--test" then
    for i = 2 to len - 1 do
      test_main Sys.argv.(i);
      print_newline ();
    done
  else (
    prerr_endline usage;
    exit 2;
  )

let () = main ()
