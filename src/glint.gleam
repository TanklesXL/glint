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
  Contents(do: Runner(a), desc: Description)
}

/// Command tree representation.
///
pub opaque type Command(a) {
  Command(
    do: Option(Contents(a)),
    subcommands: Map(String, Command(a)),
    flags: FlagMap,
  )
}

/// Creates a new command tree.
///
pub fn new() -> Command(a) {
  Command(do: None, subcommands: map.new(), flags: map.new())
}

/// Trim each path element and remove any resulting empty strings.
///
fn sanitize_path(path: List(String)) -> List(String) {
  path
  |> list.map(string.trim)
  |> list.filter(function.compose(string.is_empty, bool.negate))
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
    put: Contents(f, Description(description, usage)),
    with: flags,
  )
}

fn do_add_command(
  to root: Command(a),
  at path: List(String),
  put contents: Contents(a),
  with flags: List(Flag),
) -> Command(a) {
  case path {
    [] -> Command(..root, do: Some(contents), flags: flag.build_map(flags))
    [x, ..xs] -> {
      let update_subcommand = fn(node) {
        node
        |> option.lazy_unwrap(new)
        |> do_add_command(xs, contents, flags)
      }
      Command(
        ..root,
        subcommands: map.update(root.subcommands, x, update_subcommand),
      )
    }
  }
}

/// Ok type for command execution 
pub type Out(a) {
  /// Container for the command return value
  Out(a)
  /// Container for the generated help string
  Help(String)
}

/// Result type for command execution
pub type CmdResult(a) =
  Result(Out(a))

/// Executes the current root command.
///
fn execute_root(
  cmd: Command(a),
  args: List(String),
  flags: List(String),
) -> CmdResult(a) {
  case cmd.do {
    Some(Contents(f, _)) -> {
      try new_flags =
        flags
        |> list.try_fold(from: cmd.flags, with: flag.update_flags)
        |> snag.context("failed to run command")
      args
      |> CommandInput(new_flags)
      |> f
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
  let help_flag = flag.help_flag()

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

const flags = "FLAGS:\n\t"

const subcommands = "SUBCOMMANDS:\n\t"

const usage = "USAGE:\n\t"

// Help Message Functions
fn cmd_help(path: List(String), command: Command(a)) -> String {
  let name =
    path
    |> list.reverse
    |> string.join(" ")

  let desc = case command.do {
    None -> name
    Some(Contents(_, desc)) -> string.join([name, desc_to_string(desc)], "\n")
  }

  let flags = case map.size(command.flags) {
    0 -> ""
    _ -> string.append(flags, flag.flags_help(command.flags))
  }

  let subcommands = case map.size(command.subcommands) {
    0 -> ""
    _ -> string.append(subcommands, subcommands_help(command.subcommands))
  }

  [desc, flags, subcommands]
  |> list.filter(fn(s) { s != "" })
  |> string.join("\n\n")
}

fn desc_to_string(desc: Description) -> String {
  case desc.description, desc.usage {
    "", "" -> ""
    "", _ -> string.append(usage, desc.usage)
    _, "" -> desc.description
    _, _ -> string.concat([desc.description, "\n\n", usage, desc.usage])
  }
}

fn subcommands_help(cmds: Map(String, Command(a))) -> String {
  cmds
  |> map.map_values(subcommand_help)
  |> map.values
  |> string.join("\n\t")
}

fn subcommand_help(name: String, cmd: Command(a)) -> String {
  case cmd.do {
    None -> ""
    Some(Contents(_, Description(desc, _))) ->
      string.concat([name, "\t\t", desc])
  }
}
