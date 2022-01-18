# glint

![Github Release](https://img.shields.io/github/release/TanklesXL/glint.svg)
![Hex.pm](https://img.shields.io/hexpm/dt/glint)
![Hex.pm](https://img.shields.io/hexpm/v/glint)

Gleam command line argument parsing with basic flag support.


Find glint on [hex.pm](https://hex.pm/packages/glint).

Find the glint docs on [hexdocs.pm](https://hexdocs.pm/glint/)

## Installation

To install from hex:

```sh
gleam add glint
```

## Usage

You can import `glint` as a dependency and use it as follows:
(found in `examples/hello/src/hello.gleam` directory)
```rust
import gleam/io
import gleam/map
import gleam/string.{join, uppercase}
import gleam/erlang.{start_arguments}
import glint.{CommandInput}
import glint/flag

pub fn main() {
  let hello = fn(input: CommandInput) {
    assert Ok(flag.B(caps)) = map.get(input.flags, "caps")
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

  glint.new()
  |> glint.add_command([], hello, [flag.bool("caps", False)])
  |> glint.run(start_arguments())
}
```

Run it with either of:

- `gleam run Bob` which will print `Hello, Bob!`
- `gleam run -- --caps=true Bob` which will print `HELLO, BOB!`

*Note*: Due to [this issue](https://github.com/gleam-lang/gleam/issues/1457) commands with flags after `gleam run` must include the `--` as shown above 