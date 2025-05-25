import gleam/io
import gleam/option
import glint.{type Out, Help, Out, Version}

@external(erlang, "erlang", "halt")
@external(javascript, "node:process", "exit")
fn do_exit(status: Int) -> a

pub fn exit(res: Result(a, b)) -> a {
  case res {
    Ok(a) -> a
    Error(_) -> do_exit(1)
  }
}

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
