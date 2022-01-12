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
  |> glint.add_command([], hello_world, [flag.bool("caps", False)])
  |> glint.run(start_arguments())
}
