# glint

<a href="https://github.com/TanklesXL/glint/releases"><img src="https://img.shields.io/github/release/TanklesXL/glint.svg" alt="GitHub release"></a>

Gleam command line argument parsing with basic flag support.

## Installation

If available on Hex this package can be added to your Gleam project.

```sh
gleam add glint
```

## Usage

You can import `glint` as a dependency and use it as follows:

```rust
import gleam/io
import gleam/map
import gleam/erlang.{start_arguments}
import glint.{CommandInput}
import glint/flag

pub fn main() {
  let hello_world = fn(input: CommandInput) {
    assert Ok(flag.BoolFlag(caps)) = map.get(input.flags, "caps")

    case caps {
      True -> io.println("HELLO, WORLD!")
      False -> io.println("Hello, World!")
    }
  }

  glint.new()
  |> glint.add_command([], hello_world, [flag.string("caps", False)])
  |> glint.run(start_arguments())
}
```

Run it with either of:

- `gleam run` which will print `Hello, World!`
- `gleam run -- --caps=true` which will print `HELLO, WORLD!`
