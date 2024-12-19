//// This module demonstrates a simple glint app with 2 commands

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
    [name] -> name
    [name_1, name_2] -> name_1 <> " and " <> name_2
    [name, ..names] -> do_join_names(names, name)
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
pub fn hello(names: List(String), caps: Bool, repeat: Int) -> String {
  greet("Hello", names, caps, repeat)
}

pub fn greet(
  greeting: String,
  names: List(String),
  caps: Bool,
  repeat: Int,
) -> String {
  { greeting <> ", " <> join_names(names) <> "!" }
  |> capitalize(caps)
  |> list.repeat(repeat)
  |> string.join("\n")
}

// ----- CLI SETUP -----

/// a boolean flag with default False to control message capitalization.
///
pub fn caps_flag() -> glint.Parameter(Bool, glint.Flag) {
  glint.bool("caps")
  |> glint.default(False)
  |> glint.param_help("Capitalize the hello message")
}

/// an int flag with default 1 to control how many times to repeat the message.
/// this flag is constrained to values greater than 0.
///
pub fn repeat_flag() -> glint.Parameter(Int, glint.Flag) {
  use n <- glint.constraint(
    glint.int("repeat")
    |> glint.default(1)
    |> glint.param_help("Repeat the message n-times"),
  )
  case n {
    _ if n > 0 -> Ok(n)
    _ -> Error(snag.new("repeat value must be a positive integer"))
  }
}

/// the command function that will be executed as the root command
///
pub fn hello_cmd() -> glint.Command(String) {
  use <- glint.command_help("Prints Hello, <names>!")
  use <- glint.min_args("names", 1, "Names of people to greet.")
  use _, args, flags <- glint.command()
  let assert Ok(caps) = glint.get_flag(flags, caps_flag())
  let assert Ok(repeat) = glint.get_flag(flags, repeat_flag())
  hello(args, caps, repeat)
}

pub fn hello_custom_cmd() -> glint.Command(String) {
  use <- glint.command_help("Prints a greeting for the names provided!")
  use greeting <- glint.named_arg(
    glint.string("greeting") |> glint.param_help("The greeting to give."),
  )
  use <- glint.min_args("names", 1, "Names of people to greet.")
  use named_args, args, flags <- glint.command()
  let assert Ok(caps) = glint.get_flag(flags, caps_flag())
  let assert Ok(repeat) = glint.get_flag(flags, repeat_flag())
  greet(greeting(named_args), args, caps, repeat)
}

/// the command function that will be executed as the "single" command
///
pub fn hello_single_cmd() -> glint.Command(String) {
  use <- glint.command_help("Prints Hello, <name>!")
  use <- glint.no_args()
  use name <- glint.named_arg(
    glint.string("name")
    |> glint.param_help("The name of the person we're saying hello to."),
  )
  use named_args, _, flags <- glint.command()
  let assert Ok(caps) = glint.get_flag(flags, caps_flag())
  let assert Ok(repeat) = glint.get_flag(flags, repeat_flag())
  let name = name(named_args)
  hello([name], caps, repeat)
}

// the function that describes our cli structure
pub fn app() {
  // create a new glint instance
  glint.new()
  // with an app name of "hello", this is used when printing help text
  |> glint.with_name("examples/hello")
  // apply global help text to all commands
  |> glint.global_help("It's time to say hello!")
  // show in usage text that the current app is run as a gleam module
  |> glint.as_module
  // with pretty help enabled, using the built-in colours
  |> glint.with_default_header_style
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
  |> glint.add(
    // add the hello custom command
    at: ["custom"],
    do: hello_custom_cmd(),
  )
}

pub fn main() {
  // run with a handler that prints the command output
  glint.run_and_handle(app(), argv.load().arguments, io.println)
}
