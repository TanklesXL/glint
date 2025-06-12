import gleam/io
import glint.{type Out}
import snag

@external(erlang, "erlang", "halt")
@external(javascript, "node:process", "exit")
fn do_exit(status: Int) -> a

/// This is a convenience function for exiting when the glint output output is Info or Failure.
/// For convenience, this function returns the inner value if the Result is Out(a).
///
/// ### Example:
///
/// ```gleam
/// cli
/// |> glint.run(args)
/// |> glintio.exit
/// ```
///
pub fn exit(res: glint.Out(a)) -> a {
  case res {
    glint.Success(a) -> a
    glint.Info(_) -> do_exit(0)
    glint.Failure(_) -> do_exit(1)
  }
}

/// Prints the result of executing a Glint application, including the command output value.
/// This function accepts as input a function to convert the command output to a String before printing it.
///
/// If you do not wish to print the command execution result, but still want to print the help or error text, see the [print_ignore_output](#print_ignore_output) function.
pub fn print(res: Out(a), f: fn(a) -> String) -> Out(a) {
  case res {
    glint.Success(o) -> f(o)
    glint.Info(s) -> s
    glint.Failure(s) -> snag.pretty_print(s)
  }
  |> io.println

  res
}

/// Prints the result of executing a Glint application.
/// This function accepts as input a function to convert the output value to a String before printing it.
///
/// If you also wish to print the command execution result, see the [print](#print) function.
pub fn print_ignore_output(res: Out(a)) -> Out(a) {
  case res {
    glint.Success(_) -> Nil
    glint.Info(s) -> io.println(s)
    glint.Failure(s) -> s |> snag.pretty_print |> io.println
  }

  res
}
