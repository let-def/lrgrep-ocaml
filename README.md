# lrgrep-ocaml

Applying LRGrep to OCaml frontend:
- [parser_raw.mly](src/parser_raw.mly) and [lexer_raw.mll](src/lexer_raw.mll) define an OCaml 5.3 compatible grammar with most syntax error reporting removed
- [parse_errors.mlyl](src/parse_errors.mlyl) define the error rules for this grammar
- the [frontend](src/frontend.ml) binary is an alternative parser that can be used with
  ocamlc/ocamlopt 5.3 (using the `-pp <path-to-frontend.exe>` flag)
- the [interpreter](src/interpreter.ml) binary is a tool that takes an incorrect input and
  prints detailed information on the parsing process at the point of failure,
  useful for devising good error patterns

## Working on OCaml grammar

For now, the main focus is on the [ocaml]() sub-directory, and
[src/parse_errors.mlyl]() specifically.

My current workflow is as follow:

- starts from an example, an OCaml code with a syntax error for which the
  message is quite bad
- by reading the [grammar](src/parser_raw.mly) and the output of the interpreter, get an idea of
  what the parsing situation looks like around the error point
- craft an error rule, and debug it using by passing `-pp frontend` to  `ocamlc` 

### Setting up the tools

All the work is done using OCaml 5.3. Make sure you are using the right switch:

```bash
$ ocamlc -version
5.3.0
```

Clone the repository and install dependencies:

```bash
$ git clone https://github.com/let-def/lrgrep.git
$ cd lrgrep
$ opam install menhir fix cmon
```

At this point, `make` should succeed (contact me if not) and produce the three binaries: `lrgrep.exe`, `frontend.bc` and `interpreter.exe`.

It is usually better to test with the bytecode frontend as it leads to shorter iteration cycles.

#### Quick test

Try the new frontend with some simple examples:

```
$ ocamlc -c -pp _build/default/src/frontend.bc test_ok.ml
```
This first example compiled successfully.

```
$ ocamlc -c -pp _build/default/src/frontend.bc test_ko_01.ml
ocamlc -pp _build/default/src/frontend.bc test_ko_01.ml
File "test_ko_01.ml", line 4, characters 0-3:
4 | let z = 7
    ^^^
Error: Spurious semi-colon at 2:9

File "test_ko_01.ml", line 1:
Error: Error while running external preprocessor
Command line: _build/default/src/frontend.bc 'test_ko_01.ml' > /tmp/ocamlppbbc3f9
```

In this one however, there is a syntax error. Luckily, this case is covered by a rule: while the error happens on line 4, it is likely caused by the semi-colon at the end of line 2.

#### Using the frontend for compiling ocaml files

By using the `OCAMLPARAM` environment variable, we can instruct all execution of ocaml compilers in the current shell to use our frontend.

```shell
$ ./demo/setup_shell.sh
export 'OCAMLPARAM=pp=$PWD/lrgrep/_build/default/src/frontend.bc,_'
# setup_shell commands produces a suitable OCAMLPARAM value
$ eval `./demo/setup_shell.sh`
$ ocamlc test_ko_01.ml
...
Error: Spurious semi-colon at 2:9
...
# In the updated environment, the new frontend is picked up automatically
```

Now you are ready to iterate on [src/parse_errors.mlyl]() to produce new rules.

**Note: `unset OCAMLPARAM` to switch back to the normal frontend**

## Devising new rules

Once you made sure your setup is working (`make` is (re-)building the frontend and `ocamlc` is using it), you can proceed to [DEVISING-RULES.md](DEVISING-RULES.md) to get started with the error DSL and the associated workflow.

## LRgrep commands

The binary offers three sub-commands: `compile`, `enumerate` and `interpret`. The sub-command that is selected is the first argument on the command line. It defaults to `compile` if the first argument is not a command.

### Compile 

`compile` is the default command and is used to generate an error matcher from a grammar and an error specification. It can also check grammar error coverage.

### Enumerate

The `enumerate` command produces a list of sentences that cover all local error situations. Use it to get intuitions about the failure paths of a grammar or to fuzz a parser.

On the calc example:

```shell
$ dune build examples/calc/parser.cmly
$ dune exec lrgrep enumerate -- -g _build/default/examples/calc/parser.cmly
```

### Interpret

The `interpret` command takes a (compiled) grammar and a sample input and produces an annotated stack.

It is useful to generalize a specific error to a class of error, by looking at the possible reductions and ignoring the parts of the input that are irrelevant to the error at hand.

The input begins with the entrypoint of the grammar and is written as a list of terminals terminated by "." (or EOF).

On the calc example:

```shell
$ dune build examples/calc/parser.cmly
$ dune exec lrgrep interpret -- -g _build/default/examples/calc/parser.cmly -
  main LPAREN INT PLUS INT .
```

Output:

```shell
Parser stack (most recent first):
		  [expr: INT .]
- line 1:21-24	INT
		 ↱ expr
- line 1:16-20	PLUS
- line 1:5-15	expr
		 ↱ expr
- line 1:5-11	LPAREN
- line 1:0-4	main
```
