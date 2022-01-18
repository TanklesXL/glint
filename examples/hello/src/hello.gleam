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
