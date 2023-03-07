import gleam/io
import gleam/map
import gleam/string.{join, uppercase}
import gleam/erlang.{start_arguments}
import glint.{CommandInput}
import glint/flag
import gleam/function.{identity}

fn hello(input: CommandInput) -> Nil {
  let assert Ok(flag.B(caps)) = flag.get(from: input.flags, for: "caps")
  let args = case input.args {
    [] -> ["World"]
    args -> args
  }

  ["Hello,", ..args]
  |> join(" ")
  |> case caps {
    True -> uppercase
    False -> identity
  }
  |> string.append("!")
  |> io.println()
}

pub fn main() {
  glint.new()
  |> glint.with_pretty_help(glint.default_pretty_help)
  |> glint.add_command(
    at: [],
    do: hello,
    with: [flag.bool("caps", False, "Capitalize the provided name")],
    described: "Prints Hello, <NAME>!",
  )
  |> glint.run(start_arguments())
}
