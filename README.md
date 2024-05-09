# glint

> [!WARNING]
> This README is being updated in preparation for glint `v1.0.0`. For documentation on the latest released glint versions please see [hexdocs](https://hexdocs.pm/glint/).

[![Hex Package](https://img.shields.io/hexpm/v/glint?color=ffaff3&label=%F0%9F%93%A6)](https://hex.pm/packages/glint)
[![Hex.pm](https://img.shields.io/hexpm/dt/glint?color=ffaff3)](https://hex.pm/packages/glint)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3?label=%F0%9F%93%9A)](https://hexdocs.pm/glint/)
[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/tanklesxl/glint/main)](https://github.com/tanklesxl/glint/actions)

Gleam command-line argument parsing with flags and automatic help text.

## Installation

To install from hex:

```sh
gleam add glint
```

## Usage

Glint has 3 main concepts (see below for more details): glint itself, commands and flags.

The general workflow involves

1. creating a new glint instance with `glint.new`
1. configuring it
1. creating commands with `glint.command`
   - attach flags with `glint.flag`
   - set named args with `glint.named_arg`
   - set unnamed args with `glint.unnamed_args`
1. attach the commands to glint with `glint.add`
1. run your glint app with `glint.run` or `glint.run_and_handle`

### Help text

_**Note**_:Help text is generated and printed whenever a glint command is called with the built-in flag `--help`. It is also printed after the error text when any errors are encountered due to invalid flags or arguments.

Help text descriptions can be attached to all of glint's components:

- attach global help text with `glint.global_help`
- attach comand help text with `glint.command_help`
- attach flag help text with `glint.flag_help`
- attach help text to a non-initialized command with `glint.path_help`

### Mini Example

You can import `glint` as a dependency and use it to build command-line applications like the following simplified version of the [the hello world example](./test/examples/hello.gleam).

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

// this function returns the builder for the caps flag
fn caps_flag() -> glint.Flag(Bool) {
  // create a new boolean flag with key "caps"
  // this flag will be called as --caps=true (or simply --caps as glint handles boolean flags in a bit of a special manner) from the command line
  glint.bool_flag("caps")
  // set the flag default value to False
  |> glint.flag_default(False)
  //  set the flag help text
  |> glint.flag_help("Capitalize the hello message")
}

/// the glint command that will be executed
///
fn hello() -> glint.Command(Nil) {
  // set the help text for the hello command
  use <- glint.command_help("Prints Hello, <NAME>!")
  // register the caps flag with the command
  // the `caps` variable there is a type-safe getter for the flag value
  use caps <- glint.flag(caps_flag())
  // start the body of the command
  // this is what will be executed when the command is called
  use _, args, flags <- glint.command()
  // we can assert here because the caps flag has a default
  // and will therefore always have a value assigned to it
  let assert Ok(caps) = caps(flags)
  // this is where the business logic of our command starts
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

## Glint at-a-glance

### Glint core: `glint.Glint(a)`

`glint` is conceptually quite small, your general flow will be:

- create a new glint instance with `glint.new`.
- configure glint with functions like `glint.with_pretty_help`.
- add commands with `glint.add`.
- run your cli with `glint.run`, run with a function to handle command output with `glint.run_and_handle`.

### Glint commands: `glint.Command(a)`

_Note_: Glint commands are most easily set up by chaining functions with `use`. (See the above example)

- Create a new command with `glint.command`.
- Set the command description with `glint.command_help`.
- Add a flag to a command with `glint.flag`.
- Create a named argumend with `glint.named_arg`.
- Set the expectation for unnamed args with `glint.unnamed_args`.

### Glint flags: `glint.Flag(a)`

Glint flags are a type-safe way to provide options to your commands.

- Create a new flag with a typed flag constructor function:

  - `glint.int_flag`: `glint.Flag(Int)`
  - `glint.ints_flag`: `glint.Flag(List(Int))`
  - `glint.float_flag`: `glint.Flag(Float)`
  - `glint.floats_flag`: `glint.Flag(List(Floats))`
  - `glint.string_flag`: `glint.Flag(String)`
  - `glint.strings_flag`: `glint.Flag(List(String))`
  - `glint.bool_flag`: `glint.Flag(Bool)`

- Set the flag description with `glint.flag_help`
- Set the flag default value with `glint.flag_default`, **note**: it is safe to use `let assert` when fetching values for flags with default values.
- Add a flag to a command with `glint.flag`.
- Add a `constraint.Constraint(a)` to a `glint.Flag(a)` with `glint.flag_constraint`

#### Glint flag constraints: `constraint.Constraint(a)`

Constraints are functions of shape `fn(a) -> Result(a, snag.Snag)` that are executed after a flag value has been successfully parsed, all constraints applied to a flag must succeed for that flag to be successfully processed.

Constraints can be any function so long as it satisfies the required type signature, and are useful for ensuring that data is correctly shaped **before** your glint commands are executed. This reduces unnecessary checks polluting the business logic of your commands.

Here is an example of a constraint that guarantees a processed integer flag will be a positive number.

_Note_ that constraints can both nicely be set up via pipes (`|>`) or with `use`.

```gleam
import glint
import snag
// ...
// with pipes
glint.int_flag("my_int")
|> glint.flag_default(0)
|> glint.constraint(fn(i){
  case i < 0 {
    True -> snag.error("cannot be negative")
    False -> Ok(i)
  }
})
// or
// with use
use i <- glint.flag_constraint(
  glint.int_flag("my_int")
  |> glint.flag_default(0)
)
case i < 0 {
  True -> snag.error("cannot be negative")
  False -> Ok(i)
}
```

The `glint/constraint` module provides a few helpful utilities for applying constraints, namely

- `constraint.one_of`: ensures that a value is one of some list of allowed values.
- `constraint.none_of`: ensures that a value is not one of some list of disallowed values.
- `constraint.each`: applies a constraint on individual items in a list of values (useful for applying constraints like `one_of` and `none_of` to lists.

The following example demonstrates how to constrain a `glint.Flag(List(Int))` to only allow the values 1, 2, 3 or 4 by combining `constraint.each` with `constraint.one_of`

```gleam
import glint
import glint/constraint
import snag
// ...
glint.ints_flag("my_ints")
|> glint.flag_default([])
|> glint.flag_constraint(
  [1, 2, 3, 4]
  |> constraint.one_of
  |> constraint.each
)
```

## ✨ Complementary packages

Glint works amazingly with these other packages:

- [argv](https://github.com/lpil/argv), use this for cross-platform argument fetching
- [gleescript](https://github.com/lpil/gleescript), use this to generate erlang escripts for your applications
