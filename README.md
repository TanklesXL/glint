# glint

[![Hex Package](https://img.shields.io/hexpm/v/glint?color=ffaff3&label=%F0%9F%93%A6)](https://hex.pm/packages/glint)
[![Hex.pm](https://img.shields.io/hexpm/dt/glint?color=ffaff3)](https://hex.pm/packages/glint)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3?label=%F0%9F%93%9A)](https://hexdocs.pm/glint/)
[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/tanklesxl/glint/test)](https://github.com/tanklesxl/glint/actions)

Gleam command line argument parsing with basic flag support.

## Installation

To install from hex:

```sh
gleam add glint
```

## Usage

You can import `glint` as a dependency and use it as follows:
(found in `examples/hello/src/hello.gleam` directory)

```gleam
import gleam/io
import gleam/map
import gleam/string.{join, uppercase}
import gleam/erlang.{start_arguments}
import glint.{CommandInput}
import glint/flag

fn hello(input: CommandInput) {
  assert Ok(flag.B(caps)) = flag.get_value(from: input.flags, for: "caps")
  let to_say = ["Hello,", ..input.args]
  case caps {
    True ->
      to_say
      |> join(" ")
      |> uppercase()

    False -> join(to_say, " ")
  }
  |> string.append("!")
  |> io.println()
}

pub fn main() {
  glint.new()
  |> glint.add_command(
    at: [],
    do: hello,
    with: [flag.bool("caps", False, "Capitalize the provided name")],
    described: "Prints Hello, <NAME>!",
    used: "'gleam run <NAME>' or 'gleam run <NAME> --caps'",
  )
  |> glint.run(start_arguments())
}

```

Run it with either of:

- `gleam run Bob` or `gleam run -- --caps=false Bob`  which will print `Hello, Bob!`
- `gleam run -- --caps Bob` or  `gleam run -- --caps=true Bob`  which will print `HELLO, BOB!`

*Note*: Due to [this issue](https://github.com/gleam-lang/gleam/issues/1457) commands with flags immediately after `gleam run` must include the `--` as shown above
