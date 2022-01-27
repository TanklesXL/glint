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
        node
        |> option.lazy_unwrap(new)
        |> add_command(xs, f, flags)
      }
      Command(
        ..root,
        subcommands: map.update(root.subcommands, x, update_subcommand),
      )
    }
  }
}

/// Execute the current root command.
fn execute_root(
  cmd: Command,
  args: List(String),
  flags: List(String),
) -> Result(Nil) {
  case cmd.do {
    Some(f) -> {
      try new_flags =
        list.try_fold(over: flags, from: cmd.flags, with: flag.update_flags)
        |> snag.context("failed to run command")
      Ok(f(CommandInput(args, new_flags)))
    }

    None ->
      Error(
        snag.new("command not found")
        |> snag.layer("failed to run command"),
      )
  }
}

/// Determines which command to run and executes it.
/// Sets any provided flags if necessary.
/// Flags are parsed as any value starting with a '--'
pub fn execute(cmd: Command, args: List(String)) -> Result(Nil) {
  let #(flags, args) = list.partition(args, string.starts_with(_, "--"))
  do_execute(cmd, args, flags)
}

fn do_execute(
  cmd: Command,
  args: List(String),
  flags: List(String),
) -> Result(Nil) {
  case args {
    [] -> execute_root(cmd, [], flags)
    [arg, ..rest] ->
      case map.get(cmd.subcommands, arg) {
        Ok(cmd) -> do_execute(cmd, rest, flags)
        Error(_) -> execute_root(cmd, args, flags)
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
