import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/io
import gleam/int
import gleam/result
import gleam/string
import gleam/bool
import gleam/function
import gleam
import snag.{Result}
import glint/flag.{Flag, Map as FlagMap}

/// Input type for `Runner`.
///
pub type CommandInput {
  CommandInput(args: List(String), flags: FlagMap)
}

/// Function type to be run by `glint`.
///
pub type Runner(a) =
  fn(CommandInput) -> a

pub type Description {
  Description(description: String, usage: String)
}

pub type Contents(a) {
  Contents(do: Runner(a), flags: FlagMap, desc: Description)
}

/// Command tree representation.
///
pub opaque type Command(a) {
  Command(contents: Option(Contents(a)), subcommands: Map(String, Command(a)))
}

/// Creates a new command tree.
///
pub fn new() -> Command(a) {
  Command(contents: None, subcommands: map.new())
}

/// Trim each path element and remove any resulting empty strings.
///
fn sanitize_path(path: List(String)) -> List(String) {
  path
  |> list.map(string.trim)
  |> list.filter(is_not_empty)
}

/// Adds a new command to be run at the specified path.
///
/// If the path is [], the root command is set with the provided function and
/// flags.
///
pub fn add_command(
  to root: Command(a),
  at path: List(String),
  do f: Runner(a),
  with flags: List(Flag),
  described description: String,
  used usage: String,
) -> Command(a) {
  path
  |> sanitize_path
  |> do_add_command(
    to: root,
    put: Contents(f, flag.build_map(flags), Description(description, usage)),
  )
}

fn do_add_command(
  to root: Command(a),
  at path: List(String),
  put contents: Contents(a),
) -> Command(a) {
  case path {
    // update current command with provided contents
    [] -> Command(..root, contents: Some(contents))
    // continue down the path, creating empty command nodes along the way
    [x, ..xs] -> {
      let update_subcommand = fn(node) {
        node
        |> option.lazy_unwrap(new)
        |> do_add_command(xs, contents)
      }
      Command(
        ..root,
        subcommands: map.update(root.subcommands, x, update_subcommand),
      )
    }
  }
}

/// Ok type for command execution 
///
pub type Out(a) {
  /// Container for the command return value
  Out(a)
  /// Container for the generated help string
  Help(String)
}

/// Result type for command execution
///
pub type CmdResult(a) =
  Result(Out(a))

/// Executes the current root command.
///
fn execute_root(
  cmd: Command(a),
  args: List(String),
  flags: List(String),
) -> CmdResult(a) {
  case cmd.contents {
    Some(contents) -> {
      try new_flags =
        flags
        |> list.try_fold(from: contents.flags, with: flag.update_flags)
        |> snag.context("failed to run command")
      args
      |> CommandInput(new_flags)
      |> contents.do
      |> Out
      |> Ok
    }
    None ->
      snag.error("command not found")
      |> snag.context("failed to run command")
  }
}

/// Determines which command to run and executes it.
///
/// Sets any provided flags if necessary.
///
/// Each value prefixed with `--` is parsed as a flag.
///
pub fn execute(cmd: Command(a), args: List(String)) -> CmdResult(a) {
  // create help flag to check for
  let help_flag = help_flag()

  // check if help flag is present
  let #(help, args) = case list.pop(args, fn(s) { s == help_flag }) {
    Ok(#(_, args)) -> #(True, args)
    _ -> #(False, args)
  }

  // split flags out from the args list
  let #(flags, args) = list.partition(args, string.starts_with(_, flag.prefix))

  // search for command and execute
  do_execute(cmd, args, flags, help, [])
}

fn do_execute(
  cmd: Command(a),
  args: List(String),
  flags: List(String),
  help: Bool,
  command_path: List(String),
) -> CmdResult(a) {
  case args {
    // when there are no more available arguments
    // and help flag has been passed, generate help message
    [] if help ->
      command_path
      |> cmd_help(cmd)
      |> Help
      |> Ok

    // when there are no more available arguments
    // run the current command
    [] -> execute_root(cmd, [], flags)

    // when there are arguments remaining
    // check if the next one is a subcommand of the current command
    [arg, ..rest] ->
      case map.get(cmd.subcommands, arg) {
        // subcommand found, continue
        Ok(cmd) -> do_execute(cmd, rest, flags, help, [arg, ..command_path])
        // subcommand not found, but help flag has been passed
        // generate and return help message
        _ if help ->
          command_path
          |> cmd_help(cmd)
          |> Help
          |> Ok
        // subcommand not found, but help flag has not been passed
        // execute the current command
        _ -> execute_root(cmd, args, flags)
      }
  }
}

/// A wrapper for `execute` that discards output and prints any errors
/// encountered.
///
pub fn run(cmd: Command(a), args: List(String)) -> Nil {
  case execute(cmd, args) {
    Error(err) ->
      err
      |> snag.pretty_print
      |> io.println
    Ok(Help(help)) -> io.println(help)
    _ -> Nil
  }
}

// constants for setting up sections of the help message
const flags_heading = "FLAGS:\n\t"

const subcommands_heading = "SUBCOMMANDS:\n\t"

const usage_heading = "USAGE:\n\t"

/// Helper for filtering out empty strings
///
fn is_not_empty(s: String) -> Bool {
  s != ""
}

const help_flag_name = "help"

const help_flag_message = "--help\t\t\tPrint help information"

pub fn help_flag() -> String {
  string.append(flag.prefix, help_flag_name)
}

// Help Message Functions
fn cmd_help(path: List(String), command: Command(a)) -> String {
  // recreate the path of the current command
  // reverse the path because it is created by prepending each section as do_execute walks down the tree
  let name =
    path
    |> list.reverse
    |> string.join(" ")

  // create the name, description  and usage help block
  let #(flags, description, usage) = case command.contents {
    None -> #("", "", "")
    Some(Contents(_, flags, desc)) -> {
      // create the flags help block
      let flags =
        flags
        |> flag.flags_help()
        |> append_if_msg_not_empty("\n\t", _)
        |> string.append(help_flag_message, _)
        |> string.append(flags_heading, _)
      // create the usage help block
      let usage = append_if_msg_not_empty(usage_heading, desc.usage)
      #(flags, desc.description, usage)
    }
  }

  // create the header block from the name and description
  let header_items =
    [name, description]
    |> list.filter(is_not_empty)
    |> string.join("\n")

  // create the subcommands help block
  let subcommands =
    command.subcommands
    |> subcommands_help
    |> append_if_msg_not_empty(subcommands_heading, _)

  // join the resulting help blocks into the final help message
  [header_items, usage, flags, subcommands]
  |> list.filter(is_not_empty)
  |> string.join("\n\n")
}

fn append_if_msg_not_empty(prefix: String, message: String) -> String {
  case message {
    "" -> ""
    _ -> string.append(prefix, message)
  }
}

fn subcommands_help(cmds: Map(String, Command(a))) -> String {
  cmds
  |> map.map_values(subcommand_help)
  |> map.values
  |> list.sort(string.compare)
  |> string.join("\n\t")
}

fn subcommand_help(name: String, cmd: Command(a)) -> String {
  case cmd.contents {
    None -> name
    Some(Contents(_, _, Description(desc, _))) ->
      string.concat([name, "\t\t", desc])
  }
}
