import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/io
import gleam/string
import snag.{Result}
import glint/flag.{Flag, Map as FlagMap}
import shellout

/// Glint container type for config and commands
///
pub type Glint(a) {
  Glint(config: Config, cmd: Command(a))
}

/// Config for glint
///
pub type Config {
  Config(pretty_help: Bool)
}

/// Input type for `Runner`.
///
pub type CommandInput {
  CommandInput(args: List(String), flags: FlagMap)
}

/// Function type to be run by `glint`.
///
pub type Runner(a) =
  fn(CommandInput) -> a

///  Command description, used for generating help text
///
pub type Description {
  Description(description: String, usage: String)
}

/// Command contents
///
pub opaque type Contents(a) {
  Contents(do: Runner(a), flags: FlagMap, desc: Description)
}

/// Command tree representation.
///
pub opaque type Command(a) {
  Command(contents: Option(Contents(a)), subcommands: Map(String, Command(a)))
}

/// Create command stubs to be used in `add_command_from_stub`
///
pub type Stub(a) {
  Stub(
    path: List(String),
    run: Runner(a),
    flags: List(Flag),
    description: String,
    usage: String,
  )
}

/// Add a command to the root given a stub 
///
pub fn add_command_from_stub(to glint: Glint(a), with stub: Stub(a)) -> Glint(a) {
  add_command(
    to: glint,
    at: stub.path,
    do: stub.run,
    with: stub.flags,
    described: stub.description,
    used: stub.usage,
  )
}

/// Creates a new command tree.
///
pub fn new() -> Glint(a) {
  Glint(config: default_config(), cmd: empty_command())
}

/// Creates a new command tree with the provided Config
///
pub fn new_with_config(config: Config) -> Glint(a) {
  Glint(config: config, cmd: empty_command())
}

/// Create a default Config
///
pub fn default_config() -> Config {
  Config(pretty_help: False)
}

/// Helper for initializing empty commands
///
fn empty_command() -> Command(a) {
  Command(contents: None, subcommands: map.new())
}

pub fn enable_pretty_help(glint: Glint(a)) -> Glint(a) {
  Glint(..glint, config: Config(pretty_help: True))
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
/// Note: all command paths are sanitized by stripping whitespace and removing any empty string elements.
///
pub fn add_command(
  to glint: Glint(a),
  at path: List(String),
  do f: Runner(a),
  with flags: List(Flag),
  described description: String,
  used usage: String,
) -> Glint(a) {
  Glint(
    ..glint,
    cmd: path
    |> sanitize_path
    |> do_add_command(
      to: glint.cmd,
      put: Contents(f, flag.build_map(flags), Description(description, usage)),
    ),
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
        |> option.lazy_unwrap(empty_command)
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
pub fn execute(glint: Glint(a), args: List(String)) -> CmdResult(a) {
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
  do_execute(glint.config, glint.cmd, args, flags, help, [])
}

fn do_execute(
  config: Config,
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
      |> cmd_help(config, cmd)
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
        Ok(cmd) ->
          do_execute(config, cmd, rest, flags, help, [arg, ..command_path])
        // subcommand not found, but help flag has been passed
        // generate and return help message
        _ if help ->
          command_path
          |> cmd_help(config, cmd)
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
pub fn run(glint: Glint(a), args: List(String)) -> Nil {
  case execute(glint, args) {
    Error(err) ->
      err
      |> snag.pretty_print
      |> io.println
    Ok(Help(help)) -> io.println(help)
    _ -> Nil
  }
}

// constants for setting up sections of the help message
const flags_heading = "FLAGS:"

const subcommands_heading = "SUBCOMMANDS:"

const usage_heading = "USAGE:"

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

const lookups: shellout.Lookups = [
  #(
    ["color", "background"],
    [
      #("buttercup", ["252", "226", "174"]),
      #("mint", ["182", "255", "234"]),
      #("pink", ["255", "175", "243"]),
    ],
  ),
]

const heading_display: List(String) = ["bold", "italic", "underline"]

fn heading_style(pretty: Bool, heading: String, colour: String) -> String {
  case pretty {
    True ->
      shellout.style(
        heading,
        with: shellout.display(heading_display)
        |> map.merge(shellout.color([colour])),
        custom: lookups,
      )
    False -> heading
  }
  |> string.append("\n\t")
}

// Help Message Functions
fn cmd_help(path: List(String), config: Config, command: Command(a)) -> String {
  // recreate the path of the current command
  // reverse the path because it is created by prepending each section as do_execute walks down the tree
  let name =
    path
    |> list.reverse
    |> string.join(" ")

  // create the name, description  and usage help block
  let #(flags, description, usage) = case command.contents {
    None -> #("", "", "")
    Some(Contents(flags: flags, desc: desc, ..)) -> {
      // create the flags help block
      let flags =
        flags
        |> flag.flags_help()
        |> append_if_msg_not_empty("\n\t", _)
        |> string.append(help_flag_message, _)
        |> string.append(
          heading_style(config.pretty_help, flags_heading, "pink"),
          _,
        )
      // create the usage help block
      let usage =
        append_if_msg_not_empty(
          heading_style(config.pretty_help, usage_heading, "mint"),
          desc.usage,
        )
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
    |> append_if_msg_not_empty(
      heading_style(config.pretty_help, subcommands_heading, "buttercup"),
      _,
    )

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
    Some(Contents(desc: Description(desc, ..), ..)) ->
      string.concat([name, "\t\t", desc])
  }
}
