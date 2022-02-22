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
