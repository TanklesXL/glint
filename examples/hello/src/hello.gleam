// stdlib imports
import gleam/io
import gleam/list
import gleam/string.{uppercase}

// external dep imports
import snag

// glint imports
import argv
import glint

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

/// a boolean flag with default False to control message capitalization.
///
pub fn caps_flag() -> glint.Flag(Bool) {
  glint.flag_bool("caps")
  |> glint.flag_default(False)
  |> glint.flag_help("Capitalize the hello message")
}

/// an int flag with default 1 to control how many times to repeat the message.
/// this flag is constrained to values greater than 0.
///
pub fn repeat_flag() -> glint.Flag(Int) {
  use n <- glint.constraint(
    glint.flag_int("repeat")
    |> glint.flag_default(1)
    |> glint.flag_help("Repeat the message n-times"),
  )
  case n {
    _ if n > 0 -> Ok(n)
    _ -> snag.error("Value must be greater than 0.")
  }
}

/// the command function that will be executed as the root command
///
pub fn hello_cmd() -> glint.Command(String) {
  use <- glint.command_help("Prints Hello, <names>!")
  use <- glint.unnamed_args(glint.MinArgs(1))
  use _, args, flags <- glint.command()
  let assert Ok(caps) = glint.get_flag(flags, caps_flag())
  let assert Ok(repeat) = glint.get_flag(flags, repeat_flag())
  let assert [name, ..rest] = args
  hello(name, rest, caps, repeat)
}

/// the command function that will be executed as the "single" command
///
pub fn hello_single_cmd() -> glint.Command(String) {
  use <- glint.command_help("Prints Hello, <name>!")
  use <- glint.unnamed_args(glint.EqArgs(0))
  use name <- glint.named_arg("name")
  use named_args, _, flags <- glint.command()
  let assert Ok(caps) = glint.get_flag(flags, caps_flag())
  let assert Ok(repeat) = glint.get_flag(flags, repeat_flag())
  let name = name(named_args)
  hello(name, [], caps, repeat)
}

// the function that describes our cli structure
pub fn app() {
  // create a new glint instance
  glint.new()
  // with an app name of "hello", this is used when printing help text
  |> glint.with_name("hello")
  // apply global help text to all commands
  |> glint.global_help("It's time to say hello!")
  // show in usage text that the current app is run as a gleam module
  |> glint.as_module
  // with pretty help enabled, using the built-in colours
  |> glint.pretty_help(glint.default_pretty_help())
  // with group level flags
  // with flag `caps` for all commands (equivalent of using glint.global_flag)
  |> glint.group_flag([], caps_flag())
  // // with flag `repeat` for all commands (equivalent of using glint.global_flag)
  |> glint.group_flag([], repeat_flag())
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
