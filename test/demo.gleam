if erlang {
  // stdlib imports
  import gleam/io
  import gleam/list
  import gleam/result
  import gleam/string.{join, uppercase}
  import gleam/function.{compose}
  // external dep imports
  import snag
  import gleam/erlang.{start_arguments}
  // glint imports
  import glint.{CommandInput}
  import glint/flag

  // the key for the caps flag
  const caps = "caps"

  // the key for the repeat flag
  const repeat = "repeat"

  fn hello(input: CommandInput) -> snag.Result(String) {
    let assert Ok(caps) = flag.get_bool(from: input.flags, for: caps)
    let assert Ok(repeat) = flag.get_int(from: input.flags, for: repeat)
    use name <- result.try(case input.args {
      [] -> snag.error("no arguments provided")
      _ -> Ok(input.args)
    })

    ["Hello,", ..name]
    |> case caps {
      True -> compose(join(_, " "), uppercase)
      False -> join(_, " ")
    }
    |> string.append("!")
    |> list.repeat(repeat)
    |> string.join("\n")
    |> Ok
  }

  /// gtz is a Constraint(Int) and ensures that the provided value is greater than zero.
  ///
  fn gtz(n: Int) -> snag.Result(Nil) {
    case n {
      _ if n > 0 -> Ok(Nil)
      _ -> snag.error("Value must be greater than 0.")
    }
  }

  pub fn main() {
    // a boolean flag with default False to control message capitalization.
    let caps_flag =
      flag.new(flag.B)
      |> flag.default(False)
      |> flag.description("Capitalize the provided name")

    // an int flag with default 1 to control how many times to repeat the message.
    // this flag has the `gtz` constraint applied to it.
    let repeat_flag =
      flag.new(flag.I)
      |> flag.default(1)
      |> flag.constraint(gtz)
      |> flag.description("Repeat the message n-times")

    // create a new glint instance
    glint.new()
    // with a root command that executes the `hello` function
    |> glint.add(
      at: [],
      do: glint.command(hello)
      // with flag `caps`
      |> glint.flag(caps, caps_flag)
      // with flag `repeat`
      |> glint.flag(repeat, repeat_flag)
      |> glint.description("Prints Hello, <NAME>!"),
    )
    // with pretty help enabled, using the built-in colours
    |> glint.with_pretty_help(glint.default_pretty_help())
    // run with a handler that converts the command output to a string and prints it
    |> glint.run_and_handle(
      start_arguments(),
      fn(res) {
        case res {
          Ok(out) -> out
          Error(err) ->
            err
            |> snag.layer("failed to execute command")
            |> snag.pretty_print()
        }
        |> io.println
      },
    )
  }
}
