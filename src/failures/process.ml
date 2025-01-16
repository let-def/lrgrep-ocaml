let split_on ~delim components =
  let rec loop acc = function
    | [] -> (List.rev acc, None)
    | x :: rest when x = delim ->
      (List.rev acc, Some rest)
    | x :: rest -> loop (x :: acc) rest
  in
  loop [] components

let split_on' ~delim c =
  match split_on ~delim c with
  | x, None -> x, []
  | x, Some xs -> x, xs

type entrypoint =
  | Implementation
  | Interface
  | Parse_any_longident
  | Parse_constr_longident
  | Parse_core_type
  | Parse_expression
  | Parse_mod_ext_longident
  | Parse_mod_longident
  | Parse_module_expr
  | Parse_module_type
  | Parse_mty_longident
  | Parse_pattern
  | Parse_val_longident
  | Toplevel_phrase
  | Use_file

let print_token = function
  | "AMPERAMPER"     -> "&&"
  | "AMPERSAND"      -> "&"
  | "AND"            -> "and"
  | "ANDOP"          -> "and+"
  | "AS"             -> "as"
  | "ASSERT"         -> "assert"
  | "AT"             -> "@"
  | "ATAT"           -> "@@"
  | "BACKQUOTE"      -> "`"
  | "BANG"           -> "!"
  | "BAR"            -> "|"
  | "BARBAR"         -> "||"
  | "BARRBRACKET"    -> "|]"
  | "BEGIN"          -> "begin"
  | "CHAR"           -> "'a'"
  | "CLASS"          -> "class"
  | "COLON"          -> ":"
  | "COLONCOLON"     -> "::"
  | "COLONEQUAL"     -> ":="
  | "COLONGREATER"   -> ":>"
  | "COLONRBRACKET"  -> ":]"
  | "COMMA"          -> ","
  | "COMMENT"        -> "(*COM*)"
  | "CONSTRAINT"     -> "constraint"
  | "DO"             -> "do"
  | "DOCSTRING"      -> "(**DOC*)"
  | "DONE"           -> "done"
  | "DOT"            -> "."
  | "DOTDOT"         -> ".."
  | "DOTOP"          -> ".+"
  | "DOWNTO"         -> "downto"
  | "ELSE"           -> "else"
  | "END"            -> "end"
  | "EOF"            -> Printf.eprintf "EOF unsupported"; ""
  | "EOL"            -> Printf.eprintf "EOL unsupported"; ""
  | "EQUAL"          -> "="
  | "EXCEPTION"      -> "exception"
  | "EXCLAVE"        -> "exclave_"
  | "EXTERNAL"       -> "external"
  | "FALSE"          -> "false"
  | "FLOAT"          -> "42.0"
  | "FOR"            -> "for"
  | "FUN"            -> "fun"
  | "FUNCTION"       -> "function"
  | "FUNCTOR"        -> "functor"
  | "GLOBAL"         -> "global_"
  | "GREATER"        -> ">"
  | "GREATERRBRACE"  -> ">}"
  | "GREATERRBRACKET" -> ">]"
  | "HASH"           -> "#"
  | "HASH_FLOAT"     -> "#42.0"
  | "HASH_INT"       -> "#42"
  | "HASHLPAREN"     -> "#("
  | "HASHOP"         -> "#+"
  | "HASH_SUFFIX"    -> Printf.eprintf "HASH_SUFFIX unsupported"; "HASH_SUFFIX"
  | "IF"             -> "if"
  | "IN"             -> "in"
  | "INCLUDE"        -> "include"
  | "INFIXOP0"       -> "$"
  | "INFIXOP1"       -> "^"
  | "INFIXOP2"       -> "+"
  | "INFIXOP3"       -> "/"
  | "INFIXOP4"       -> "**"
  | "INHERIT"        -> "inherit"
  | "INITIALIZER"    -> "initializer"
  | "INT"            -> "42"
  | "KIND_ABBREV"    -> "kind_abbrev_"
  | "KIND_OF"        -> "kind_of_"
  | "LABEL"          -> "~v:"
  | "LAZY"           -> "lazy"
  | "LBRACE"         -> "{"
  | "LBRACELESS"     -> "{<"
  | "LBRACKET"       -> "["
  | "LBRACKETAT"     -> "[@"
  | "LBRACKETATAT"   -> "[@@"
  | "LBRACKETATATAT" -> "[@@@"
  | "LBRACKETBAR"    -> "[|"
  | "LBRACKETCOLON"  -> "[:"
  | "LBRACKETGREATER" -> "[>"
  | "LBRACKETLESS"   -> "[<"
  | "LBRACKETPERCENT" -> "[@"
  | "LBRACKETPERCENTPERCENT" -> "[@@"
  | "LESS"           -> "<"
  | "LESSMINUS"      -> "<-"
  | "LET"            -> "let"
  | "LETOP"          -> "let+"
  | "LIDENT"         -> "lident"
  | "LOCAL"          -> "local_"
  | "LPAREN"         -> ")"
  | "MATCH"          -> "match"
  | "METHOD"         -> "method"
  | "MINUS"          -> "-"
  | "MINUSDOT"       -> "-."
  | "MINUSGREATER"   -> "->"
  | "MOD"            -> "mod"
  | "MODULE"         -> "module"
  | "MUTABLE"        -> "mutable"
  | "NEW"            -> "new"
  | "NONREC"         -> "nonrec"
  | "OBJECT"         -> "object"
  | "OF"             -> "of"
  | "ONCE"           -> "once_"
  | "OPEN"           -> "open"
  | "OPTLABEL"       -> "?v:"
  | "OR"             -> "or"
  | "PERCENT"        -> "%"
  | "PLUS"           -> "+"
  | "PLUSDOT"        -> "+."
  | "PLUSEQ"         -> "+="
  | "PREFIXOP"       -> "!+"
  | "PRIVATE"        -> "private"
  | "QUESTION"       -> "?"
  | "QUOTE"          -> "'"
  | "QUOTED_STRING_EXPR" -> "{%%qsi||}"
  | "QUOTED_STRING_ITEM" -> "{%%qse||}"
  | "RBRACE"         -> "}"
  | "RBRACKET"       -> "]"
  | "REC"            -> "rec"
  | "RPAREN"         -> ")"
  | "SEMI"           -> ";"
  | "SEMISEMI"       -> ";;"
  | "SIG"            -> "sig"
  | "STACK"          -> "stack_"
  | "STAR"           -> "*"
  | "STRING"         -> "\"STRING\""
  | "STRUCT"         -> "struct"
  | "THEN"           -> "then"
  | "TILDE"          -> "~"
  | "TO"             -> "to"
  | "TRUE"           -> "true"
  | "TRY"            -> "try"
  | "TYPE"           -> "type"
  | "UIDENT"         -> "UIDENT"
  | "UNDERSCORE"     -> "_"
  | "UNIQUE"         -> "unique_"
  | "VAL"            -> "val"
  | "VIRTUAL"        -> "virtual"
  | "WHEN"           -> "when"
  | "WHILE"          -> "while"
  | "WITH"           -> "with"
  | other ->
    Printf.eprintf "Unknown token %s\n" other;
    exit 1

let process_line str =
  match String.split_on_char ' ' str with
  | [] -> assert false
  | entrypoint :: rest ->
    let tokens, rest = split_on' ~delim:"@" rest in
    let lookaheads, rest = split_on' ~delim:"[" rest in
    let rec loop items = function
      | [] -> List.rev items
      | rest ->
        match split_on' ~delim:"]" rest with
        | symbols, ("[" :: rest) -> loop (symbols :: items) rest
        | symbols, [] -> List.rev (symbols :: items)
        | _ -> assert false
    in
    let items = loop [] rest in
    print_endline entrypoint;
    print_endline (String.concat " " (List.map print_token tokens));
    print_endline (String.concat " " (List.map print_token lookaheads));
    let index = ref (List.length items - 1) in
    List.iteri (fun i item ->
        if List.nth item (List.length item - 1) <> "." then
          index := i;
      ) items;
    List.iteri (fun i item ->
        if i = !index then print_string "MOST RELEVANT: ";
        print_endline (String.concat " " item);
      ) items

let rec loop () =
  match read_line () with
  | exception End_of_file -> ()
  | line ->
    process_line line;
    loop ()

let () = loop ()
