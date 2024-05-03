# glint

[![Hex Package](https://img.shields.io/hexpm/v/glint?color=ffaff3&label=%F0%9F%93%A6)](https://hex.pm/packages/glint)
[![Hex.pm](https://img.shields.io/hexpm/dt/glint?color=ffaff3)](https://hex.pm/packages/glint)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3?label=%F0%9F%93%9A)](https://hexdocs.pm/glint/)
[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/tanklesxl/glint/main)](https://github.com/tanklesxl/glint/actions)

Gleam command line argument parsing with basic flag support.

## Installation

To install from hex:

```sh
gleam add glint
```

## Usage

### Glint's Core

`glint` is conceptually quite small, your general flow will be:

1. create a new glint instance with `glint.new`
1. configure it with `glint.with_pretty_help` and other configuration functions
1. add commands with `glint.add`
   1. create a new command with `glint.command`
   1. assign that command any flags required
   1. assign the command a custom description
1. run your cli with `glnt.run`, run with a function to handle command output with `glint.run_and_handle`

## ✨ Complementary packages

Glint works amazingly with these other packages:

- [argv](https://github.com/lpil/argv), use this for cross-platform argument fetching
- [gleescript](https://github.com/lpil/gleescript), use this to generate erlang escripts for your applications

## Mini Example

You can import `glint` as a dependency and use it to build simple command-line applications like the following simplified version of the [the hello world example](https://github.com/TanklesXL/glint/tree/main/examples/hello/README.md)

```gleam
// stdlib imports
import gleam/io
import gleam/list
import gleam/result
import gleam/string.{uppercase}
// external dep imports
import snag
import argv
// glint imports
import glint
import glint/flag


// this function returns the builder for the caps flag
fn caps_flag() -> flag.FlagBuilder(Bool) {
  flag.bool("caps")
  |> flag.default(False)
  |> flag.description("Capitalize the hello message")
}

/// the glint command that will be executed
///
fn hello() -> glint.Command(Nil) {
  use <- glint.command_help("Prints Hello, <NAME>!")
  use caps <- glint.flag(caps_flag())
  use _, args, flags <- glint.command()
  let assert Ok(caps) = caps(flags)
  let name = case args {
        [] -> "Joe"
        [name,..] -> name
  }
  let msg = "Hello, " <> name <> "!"
  case caps {
    True -> uppercase(msg)
    False -> msg
  }
  |> io.println
}

pub fn main() {
  // create a new glint instance
  glint.new()
  // with an app name of "hello", this is used when printing help text
  |> glint.with_name("hello")
  // with pretty help enabled, using the built-in colours
  |> glint.with_pretty_help(glint.default_pretty_help())
  // with a root command that executes the `hello` function
  |> glint.add(at: [], do: hello)
  // execute given arguments from stdin
  |> glint.run(argv.load().arguments)
}
```
