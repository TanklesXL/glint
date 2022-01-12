import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/io
import gleam/int
import gleam/result
import gleam/string
import snag.{Result}
import glint/flag.{Flag, FlagMap}

/// Input type for Runner.
pub type CommandInput {
  CommandInput(args: List(String), flags: FlagMap)
}

/// Function type to be run by glint.
pub type Runner =
  fn(CommandInput) -> Nil

/// Command tree representation.
pub opaque type Command {
  Command(do: Option(Runner), subcommands: Map(String, Command), flags: FlagMap)
}

/// Create a new command tree.
pub fn new() -> Command {
  Command(do: None, subcommands: map.new(), flags: map.new())
}

/// Add a new command to be run at the specified path.
/// Ff the path is [] the root command is set with the provided function and flags
pub fn add_command(
  to root: Command,
  at path: List(String),
  do f: Runner,
  with flags: List(Flag),
) -> Command {
  case path {
    [] -> Command(..root, do: Some(f), flags: flag.build_map(flags))
    [x, ..xs] -> {
      let update_subcommand = fn(node) {
        case node {
          None ->
            add_command(
              Command(do: None, subcommands: map.new(), flags: map.new()),
              xs,
              f,
              flags,
            )
          Some(node) -> add_command(node, xs, f, flags)
        }
      }
      Command(
        ..root,
        subcommands: map.update(root.subcommands, x, update_subcommand),
      )
    }
  }
}

/// Execute the current root command.
fn execute_root(cmd: Command, args: List(String)) -> Result(Nil) {
  case cmd.do {
    Some(f) -> Ok(f(CommandInput(args, cmd.flags)))
    None ->
      Error(
        snag.new("command not found")
        |> snag.layer("failed to run command"),
      )
  }
}

/// Determines which command to run and executes it.
/// Sets any provided flags if necessary.
/// Flags are parsed as any value starting with a '-'
pub fn execute(cmd: Command, args: List(String)) -> Result(Nil) {
  case args {
    [] -> execute_root(cmd, [])
    [arg, ..rest] ->
      case string.starts_with(arg, "--") {
        True -> {
          try new_flags =
            flag.update_flags(cmd.flags, string.drop_left(arg, 2))
            |> snag.context("failed to run command")
          execute(Command(..cmd, flags: new_flags), rest)
        }
        False ->
          case map.get(cmd.subcommands, arg) {
            Ok(cmd) -> execute(cmd, rest)
            Error(_) -> execute_root(cmd, args)
          }
      }
  }
}

/// A wrapper for execute that prints any errors encountered.
pub fn run(cmd: Command, args: List(String)) -> Nil {
  case execute(cmd, args) {
    Ok(Nil) -> Nil
    Error(err) ->
      err
      |> snag.pretty_print()
      |> io.println()
  }
}
