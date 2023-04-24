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

You can import `glint` as a dependency and use it as follows:
(found in `test/mini_demo.gleam`, for a more complete example see `test/demo.gleam`)

```gleam
  import gleam/io
  import gleam/result
  import gleam/string.{join, uppercase}
  import gleam/function.{compose}
  import gleam/erlang.{start_arguments}
  import glint
  import glint/flag

  const caps = "caps"

  fn hello(input: glint.CommandInput) -> Nil {
    let assert Ok(caps) = flag.get_bool(from: input.flags, for: caps)

    ["Hello,", ..input.args]
    |> case caps {
      True -> compose(join(_, " "), uppercase)
      False -> join(_, " ")
    }
    |> string.append("!")
    |> io.println
  }


  pub fn main() {
    let caps_flag =
      flag.B
      |> flag.default(False)
      |> flag.new
      |> flag.description("Capitalize the provided name")

    glint.new()
    |> glint.add(
      at: [],
      do: glint.command(hello)
      |> glint.flag(caps, caps_flag)
      |> glint.description("Prints Hello, <NAME>!"),
    )
    |> glint.with_pretty_help(glint.default_pretty_help())
    |> glint.run(start_arguments())
  }
```

Run it with either of:

- `gleam run Bob`, `gleam run -- --caps=false Bob`, or `gleam run Bob --caps=false` which will print `Hello, Bob!`
- `gleam run -- --caps Bob` or `gleam run -- --caps=true Bob`, or `gleam run Bob --caps` which will print `HELLO, BOB!`

### Built-In Help messages

Run `gleam run -- --help` to print the generated help message, which in this case will look like:

```text
Prints Hello, <NAME>!

USAGE:
        'gleam run <NAME>' or 'gleam run <NAME> --caps'

FLAGS:
        --help                  Print help information
        --caps=<CAPS>           Capitalize the provided name
```

_Note_: Due to [this issue](https://github.com/gleam-lang/gleam/issues/1457) commands with flags immediately after `gleam run` must include the `--` as shown above
