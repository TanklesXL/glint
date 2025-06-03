import gleam/io
import gleam/option
import glint.{type Out, Help, Out, Version}

@external(erlang, "erlang", "halt")
@external(javascript, "node:process", "exit")
fn do_exit(status: Int) -> a

/// This is a convenience function for exiting when the input Result is an Error.
/// For convenience, this function returns the Ok value if the Result is Ok.
///
/// ### Example:
///
/// ```gleam
/// cli
/// |> glint.run(args)
/// |> glintio.exit
/// ```
///
pub fn exit(res: Result(a, b)) -> a {
  case res {
    Ok(a) -> a
    Error(_) -> do_exit(1)
  }
}

/// Prints the result of executing a Glint application, including the command output value.
/// This function accepts as input a function to convert the command output to a String before printing it.
///
/// If you do not wish to print the command execution result, but still want to print the help or error text, see the [print_ignore_output](#print_ignore_output) function.
pub fn print(res: Result(Out(a), String), f: fn(a) -> String) {
  case res {
    Ok(Out(o)) -> f(o)
    Ok(Help(s)) -> s
    Ok(Version(s)) -> option.unwrap(s, "")
    Error(s) -> s
  }
  |> io.println

  res
}

/// Prints the result of executing a Glint application.
/// This function accepts as input a function to convert the output value to a String before printing it.
///
/// If you also wish to print the command execution result, see the [print](#print) function.
pub fn print_ignore_output(
  res: Result(Out(a), String),
) -> Result(Out(a), String) {
  case res {
    Ok(Out(_)) -> Nil
    Ok(Help(s)) -> io.println(s)
    Ok(Version(s)) -> s |> option.unwrap("") |> io.println
    Error(s) -> io.println(s)
  }

  res
}
