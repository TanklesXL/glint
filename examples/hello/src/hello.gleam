// stdlib imports
import gleam/io
import gleam/list
import gleam/string.{uppercase}
// external dep imports
import snag
// glint imports
import glint
import glint/flag
// erlang-specific imports
@target(erlang)
import gleam/erlang.{start_arguments}

// ----- APPLICATION LOGIC -----

/// a helper function to join a list of names
fn join_names(names: List(String)) -> String {
  case names {
    [] -> "Joe"
    [name] -> name
    [name, ..rest] -> do_join_names(rest, name)
  }
}

// tail-recursive implementation of join_naemes
fn do_join_names(names: List(String), acc: String) {
  case names {
    [] -> acc
    [a] -> acc <> " and " <> a
    [a, ..b] -> do_join_names(b, acc <> ", " <> a)
  }
}

pub fn message(names: List(String)) {
  "Hello, " <> join_names(names) <> "!"
}

pub fn capitalize(msg, caps) -> String {
  case caps {
    True -> uppercase(msg)
    False -> msg
  }
}

/// hello is a function that 
pub fn hello(names: List(String), caps: Bool, repeat: Int) -> String {
  names
  |> message
  |> capitalize(caps)
  |> list.repeat(repeat)
  |> string.join("\n")
}

// ----- CLI SETUP -----

/// the key for the caps flag
pub const caps = "caps"

/// a boolean flag with default False to control message capitalization.
///
pub fn caps_flag() -> flag.FlagBuilder(Bool) {
  flag.new(flag.B)
  |> flag.default(False)
  |> flag.description("Capitalize the provided name")
}

/// the key for the repeat flag
pub const repeat = "repeat"

/// an int flag with default 1 to control how many times to repeat the message.
/// this flag has the `gtz` constraint applied to it.
///
pub fn repeat_flag() -> flag.FlagBuilder(Int) {
  flag.new(flag.I)
  |> flag.default(1)
  |> flag.constraint(gtz)
  |> flag.description("Repeat the message n-times")
}

/// gtz is a Constraint(Int) and ensures that the provided value is greater than zero.
///
fn gtz(n: Int) -> snag.Result(Nil) {
  case n {
    _ if n > 0 -> Ok(Nil)
    _ -> snag.error("Value must be greater than 0.")
  }
}

/// the command function that will be executed as the root command
///
pub fn hello_cmd() -> glint.Command(String) {
  {
    use input <- glint.command()
    // the caps flag has a default value, so we can be sure it will always be present
    let assert Ok(caps) = flag.get_bool(from: input.flags, for: caps)
    // the repeat flag has a default value, so we can be sure it will always be present
    let assert Ok(repeat) = flag.get_int(from: input.flags, for: repeat)
    // call the hello function with all necessary inputs
    hello(input.args, caps, repeat)
  }
  // with flag `caps`
  |> glint.flag(caps, caps_flag())
  // with flag `repeat`
  |> glint.flag(repeat, repeat_flag())
  // with flag `repeat`
  |> glint.description("Prints Hello, <NAMES>!")
}

// the function that describes our cli structure
pub fn app() {
  // create a new glint instance
  glint.new()
  // with an app name of "hello", this is used when printing help text
  |> glint.with_name("hello")
  // with pretty help enabled, using the built-in colours
  |> glint.with_pretty_help(glint.default_pretty_help())
  // with a root command that executes the `hello` function
  |> glint.add(
    // add the hello command to the root
    at: [],
    do: hello_cmd(),
  )
}

@target(erlang)
pub fn main() {
  // run with a handler that prints the command output
  glint.run_and_handle(app(), start_arguments(), io.println)
}
