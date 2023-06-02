if erlang {
  // stdlib imports
  import gleam/io
  import gleam/string.{join, uppercase}
  import gleam/function.{compose}
  // external dep imports
  import gleam/erlang.{start_arguments}
  // glint imports
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
    // a boolean flag with default False to control message capitalization.
    let caps_flag =
      flag.B
      |> flag.new
      |> flag.default(False)
      |> flag.description("Capitalize the provided name")
    // create a new glint instance
    glint.new()
    // with a root command that executes the `hello` function
    |> glint.add(
      at: [],
      do: glint.command(hello)
      // with flag `caps`
      |> glint.flag(caps, caps_flag)
      |> glint.description("Prints Hello, <NAME>!"),
    )
    // with pretty help enabled, using the built-in colours
    |> glint.with_pretty_help(glint.default_pretty_help())
    // run with a handler that ignores command output
    |> glint.run(start_arguments())
  }
}
