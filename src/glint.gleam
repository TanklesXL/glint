import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/io
import gleam/int
import gleam/result
import gleam/string
import snag.{Result}
import glint/flag.{Flag, FlagMap}

/// Input type for `Runner`.
///
pub type CommandInput {
  CommandInput(args: List(String), flags: FlagMap)
}

/// Function type to be run by `glint`.
///
pub type Runner(a) =
  fn(CommandInput) -> a

/// Command tree representation.
///
pub opaque type Command(a) {
  Command(
    do: Option(Runner(a)),
    subcommands: Map(String, Command(a)),
    flags: FlagMap,
  )
}

/// Creates a new command tree.
///
pub fn new() -> Command(a) {
  Command(do: None, subcommands: map.new(), flags: map.new())
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
) -> Command(a) {
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

/// Executes the current root command.
///
fn execute_root(
  cmd: Command(a),
  args: List(String),
  flags: List(String),
) -> Result(a) {
  case cmd.do {
    Some(f) -> {
      try new_flags =
        flags
        |> list.try_fold(from: cmd.flags, with: flag.update_flags)
        |> snag.context("failed to run command")
      args
      |> CommandInput(new_flags)
      |> f
      |> Ok
    }

    None ->
      snag.new("command not found")
      |> snag.layer("failed to run command")
      |> Error
  }
}

/// Determines which command to run and executes it.
///
/// Sets any provided flags if necessary.
///
/// Each value prefixed with `--` is parsed as a flag.
///
pub fn execute(cmd: Command(a), args: List(String)) -> Result(a) {
  let #(flags, args) = list.partition(args, string.starts_with(_, "--"))
  do_execute(cmd, args, flags)
}

fn do_execute(
  cmd: Command(a),
  args: List(String),
  flags: List(String),
) -> Result(a) {
  case args {
    [] -> execute_root(cmd, [], flags)
    [arg, ..rest] ->
      case map.get(cmd.subcommands, arg) {
        Ok(cmd) -> do_execute(cmd, rest, flags)
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
    _ -> Nil
  }
}
