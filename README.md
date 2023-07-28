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

### Glint Core

`glint` is conceptually quite small:

- `glint.new` creates a new `Glint(a)`, a container for `Command(a)` at specified paths. The `glint` module contains utility functions for configuring a `Glint(a)` such as pretty printing, as well as functions for building `Command(a)`

### Mini Example

You can import `glint` as a dependency and use it to build simple command-line applications like the following simplified version of the [the hello world example](./examples/hello/README.md)

```gleam
// stdlib imports
import gleam/io
import gleam/list
import gleam/result
import gleam/string.{uppercase}
// external dep imports
import snag
// glint imports
import glint
import glint/flag
// erlang-specific imports

@target(erlang)
import gleam/erlang.{start_arguments}

/// the key for the caps flag
const caps = "caps"

/// a boolean flag with default False to control message capitalization.
///
fn caps_flag() -> flag.FlagBuilder(Bool) {
  flag.new(flag.B)
  |> flag.default(False)
  |> flag.description("Capitalize the provided name")
}

/// the command function that will be executed
///
fn hello(input: glint.CommandInput) -> Nil {
  let assert Ok(caps) = flag.get_bool(from: input.flags, for: caps)

  let name =
    case input.args {
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
  |> glint.add(
      // add the command to the root
      at: [],
      // create the command, add any flags
      do: glint.command(hello)
      // with flag `caps`
      |> glint.flag(caps, caps_flag())
      // with flag `repeat`
      |> glint.flag(repeat, repeat_flag())
      // with a short description
      |> glint.description("Prints Hello, <NAME>!"),
  )
  |> glint.run(start_arguments())
}
```
