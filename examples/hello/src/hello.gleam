// stdlib imports
import gleam/io
import gleam/list
import gleam/string.{uppercase}
// external dep imports
import snag
// glint imports
import glint
import glint/flag
import argv

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
pub fn caps_flag() -> flag.Builder(Bool) {
  flag.bool()
  |> flag.default(False)
  |> flag.description("Capitalize the hello message")
}

/// the key for the repeat flag
pub const repeat = "repeat"

/// an int flag with default 1 to control how many times to repeat the message.
/// this flag is constrained to values greater than 0.
///
pub fn repeat_flag() -> flag.Builder(Int) {
  use n <- flag.constraint(
    flag.int()
    |> flag.default(1)
    |> flag.description("Repeat the message n-times"),
  )
  case n {
    _ if n > 0 -> Ok(n)
    _ -> snag.error("Value must be greater than 0.")
  }
}

/// the command function that will be executed as the root command
///
pub fn hello_cmd() -> glint.Command(String) {
  // register
  use <- glint.description("Prints Hello, <names>!")
  use <- glint.unnamed_args(glint.MinArgs(1))
  use _, args, flags <- glint.command()
  let assert Ok(caps) = flag.get_bool(flags, caps)
  let assert Ok(repeat) = flag.get_int(flags, repeat)
  let assert [name, ..rest] = args
  hello(name, rest, caps, repeat)
}

/// the command function that will be executed as the "single" command
///
pub fn hello_single_cmd() -> glint.Command(String) {
  use <- glint.description("Prints Hello, <name>!")
  use <- glint.unnamed_args(glint.EqArgs(0))
  use name <- glint.named_arg("name")
  use named_args, _, flags <- glint.command()
  let assert Ok(caps) = flag.get_bool(flags, caps)
  let assert Ok(repeat) = flag.get_int(flags, repeat)
  let name = name(named_args)
  hello(name, [], caps, repeat)
}

// the function that describes our cli structure
pub fn app() {
  // create a new glint instance
  glint.new()
  // with an app name of "hello", this is used when printing help text
  |> glint.name("hello")
  // show in usage text that the current app is run as a gleam module
  |> glint.as_module
  // with pretty help enabled, using the built-in colours
  |> glint.pretty_help(glint.default_pretty_help())
  // with group level flags
  // with flag `caps` for all commands (equivalent of using glint.global_flag)
  |> glint.group_flag([], caps, caps_flag())
  // // with flag `repeat` for all commands (equivalent of using glint.global_flag)
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
