// stdlib imports
import gleam/dict
import gleam/io
import gleam/list
import gleam/string.{uppercase}
// external dep imports
import snag
// glint imports
import argv
import glint
import glint/flag

// ----- APPLICATION LOGIC -----

/// a helper function to join a list of names
fn join_names(names: List(String)) -> String {
  case names {
    [] -> ""
    _ -> do_join_names(names, "")
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

pub fn capitalize(msg, caps) -> String {
  case caps {
    True -> uppercase(msg)
    False -> msg
  }
}

/// hello is a function that says hello
pub fn hello(
  primary: String,
  rest: List(String),
  caps: Bool,
  repeat: Int,
) -> String {
  { "Hello, " <> primary <> join_names(rest) <> "!" }
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
  flag.bool()
  |> flag.default(False)
  |> flag.description("Capitalize the provided name")
}

/// the key for the repeat flag
pub const repeat = "repeat"

/// an int flag with default 1 to control how many times to repeat the message.
/// this flag has the `gtz` constraint applied to it.
///
pub fn repeat_flag() -> flag.FlagBuilder(Int) {
  flag.int()
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
    // we can assert here because we have told glint that this command expects at least one argument
    let assert [name, ..rest] = input.args
    hello(name, rest, caps, repeat)
  }
  |> glint.description("Prints Hello, <names>!")
  // with at least 1 unnamed argument
  |> glint.unnamed_args(glint.MinArgs(1))
}

/// the command function that will be executed as the "single" command
///
pub fn hello_single_cmd() -> glint.Command(String) {
  {
    use input <- glint.command()

    // the caps flag has a default value, so we can be sure it will always be present
    let assert Ok(caps) = flag.get_bool(from: input.flags, for: caps)

    // the repeat flag has a default value, so we can be sure it will always be present
    let assert Ok(repeat) = flag.get_int(from: input.flags, for: repeat)

    // access named args directly
    let assert Ok(name) = dict.get(input.named_args, "name")

    // call the hello function with all necessary inputs
    hello(name, [], caps, repeat)
  }
  |> glint.description("Prints Hello, <name>!")
  // with a named arg called 'name'
  |> glint.named_args(["name"])
  // with no unnamed arguments
  |> glint.unnamed_args(glint.EqArgs(0))
}

// the function that describes our cli structure
pub fn app() {
  // create a new glint instance
  glint.new()
  // with an app name of "hello", this is used when printing help text
  |> glint.with_name("hello")
  // show in usage text that the current app is run as a gleam module
  |> glint.as_gleam_module
  // with pretty help enabled, using the built-in colours
  |> glint.with_pretty_help(glint.default_pretty_help())
  // with group level flags
  // with flag `caps` for all commands (equivalent of using glint.global_flag)
  |> glint.group_flag([], caps, caps_flag())
  // with flag `repeat` for all commands (equivalent of using glint.global_flag)
  |> glint.group_flag([], repeat, repeat_flag())
  // with a root command that executes the `hello` function
  |> glint.add(
    // add the hello command to the root
    at: [],
    do: hello_cmd(),
  )
  |> glint.add(
    // add the hello single command
    at: ["single"],
    do: hello_single_cmd(),
  )
}

pub fn main() {
  // run with a handler that prints the command output
  glint.run_and_handle(app(), argv.load().arguments, io.println)
}
