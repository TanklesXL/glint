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

  const caps = "caps"

  const repeat = "repeat"

  /// hello is the root command for 
  fn hello(input: CommandInput) -> snag.Result(String) {
    use caps <- result.then(flag.get_bool(from: input.flags, for: caps))
    use repeat <- result.then(flag.get_int(from: input.flags, for: repeat))
    use name <- result.then(case input.args {
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

  fn result_to_string(res: snag.Result(String)) -> String {
    case res {
      Ok(out) -> out
      Error(err) -> snag.pretty_print(err)
    }
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
      flag.new(of: flag.B)
      |> flag.desc("Capitalize the provided name")

    // an int flag with default 1 to control how many times to repeat the message.
    // this flag has the `gtz` constraint applied to it.
    let repeat_flag =
      flag.new(
        of: flag.I
        |> flag.default(1)
        |> flag.constraint(gtz),
      )
      |> flag.desc("Repeat the message n-times")

    // create a new glint instance
    glint.new()
    // with a root command that executes the `hello` function
    // with flags `caps` and `repeat`
    |> glint.add(
      at: [],
      do: glint.cmd(hello)
      |> glint.flag(caps, caps_flag)
      |> glint.flag(repeat, repeat_flag)
      |> glint.desc("Prints Hello, <NAME>!"),
    )
    // with pretty help enabled, using the built-in colours
    |> glint.with_pretty_help(glint.default_pretty_help())
    // run with a handler that converts the command output to a string and prints it
    |> glint.run_and_handle(
      start_arguments(),
      compose(result_to_string, io.println),
    )
  }
}
