import gleam/bool
import gleam/dict
import gleam/option.{type Option, None, Some}
import gleam/list
import gleam/io
import gleam/int
import gleam/string
import snag.{type Result}
import glint/flag.{type Flag, type Map as FlagMap}
import gleam/string_builder as sb
import gleam_community/ansi
import gleam_community/colour.{type Colour}
import gleam/result
import gleam

// --- CONFIGURATION ---

// -- CONFIGURATION: TYPES --

/// Config for glint
///
pub type Config {
  Config(
    pretty_help: Option(PrettyHelp),
    name: Option(String),
    as_gleam_module: Bool,
  )
}

/// PrettyHelp defines the header colours to be used when styling help text
///
pub type PrettyHelp {
  PrettyHelp(usage: Colour, flags: Colour, subcommands: Colour)
}

// -- CONFIGURATION: CONSTANTS --

/// Default config
///
pub const default_config = Config(
  pretty_help: None,
  name: None,
  as_gleam_module: False,
)

// -- CONFIGURATION: FUNCTIONS --

/// Add the provided config to the existing command tree
///
pub fn with_config(glint: Glint(a), config: Config) -> Glint(a) {
  Glint(..glint, config: config)
}

/// Enable custom colours for help text headers
/// For a pre-made colouring use `default_pretty_help()`
///
pub fn with_pretty_help(glint: Glint(a), pretty: PrettyHelp) -> Glint(a) {
  Config(..glint.config, pretty_help: Some(pretty))
  |> with_config(glint, _)
}

/// Disable custom colours for help text headers
///
pub fn without_pretty_help(glint: Glint(a)) -> Glint(a) {
  Config(..glint.config, pretty_help: None)
  |> with_config(glint, _)
}

/// Give the current glint application a name
///
pub fn with_name(glint: Glint(a), name: String) -> Glint(a) {
  Config(..glint.config, name: Some(name))
  |> with_config(glint, _)
}

/// Adjust the generated help text to reflect that the current glint app should be run as a gleam module.
/// Use in conjunction with `glint.with_name` to get usage text output like `gleam run -m <name>`
pub fn as_gleam_module(glint: Glint(a)) -> Glint(a) {
  Config(..glint.config, as_gleam_module: True)
  |> with_config(glint, _)
}

// --- CORE ---

// -- CORE: TYPES --

/// Glint container type for config and commands
///
pub opaque type Glint(a) {
  Glint(config: Config, cmd: CommandNode(a))
}

/// Specify the expected number of arguments with this type and the `glint.unnamed_args` function
///
pub type ArgsCount {
  /// Specifies that a command must accept a specific number of arguments
  ///
  EqArgs(Int)
  /// Specifies that a command must accept a minimum number of arguments
  ///
  MinArgs(Int)
}

/// A glint command
///
pub opaque type Command(a) {
  Command(
    do: Runner(a),
    flags: FlagMap,
    description: String,
    unnamed_args: Option(ArgsCount),
    named_args: List(String),
  )
}

/// The input type for `Runner`.
///
/// Arguments passed to `glint` are provided as the `args` field.
///
/// Flags passed to `glint` are provided as the `flags` field.
///
/// If named arguments are specified at command creation, they will be accessible via the `named_args` field.
/// IMPORTANT: Arguments matched by `named_args` will not be present in the `args` field.
///
pub type CommandInput {
  CommandInput(
    args: List(String),
    flags: FlagMap,
    named_args: dict.Dict(String, String),
  )
}

/// Function type to be run by `glint`.
///
pub type Runner(a) =
  fn(CommandInput) -> a

/// CommandNode tree representation.
///
type CommandNode(a) {
  CommandNode(
    contents: Option(Command(a)),
    subcommands: dict.Dict(String, CommandNode(a)),
    group_flags: FlagMap,
  )
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
  gleam.Result(Out(a), String)

// -- CORE: BUILDER FUNCTIONS --

/// Creates a new command tree.
///
pub fn new() -> Glint(a) {
  Glint(config: default_config, cmd: empty_command())
}

/// Adds a new command to be run at the specified path.
///
/// If the path is `[]`, the root command is set with the provided function and
/// flags.
///
/// Note: all command paths are sanitized by stripping whitespace and removing any empty string elements.
///
pub fn add(
  to glint: Glint(a),
  at path: List(String),
  do contents: Command(a),
) -> Glint(a) {
  Glint(
    ..glint,
    cmd: path
    |> sanitize_path
    |> do_add(to: glint.cmd, put: contents),
  )
}

/// Recursive traversal of the command tree to find where to puth the provided command
///
fn do_add(
  to root: CommandNode(a),
  at path: List(String),
  put contents: Command(a),
) -> CommandNode(a) {
  case path {
    // update current command with provided contents
    [] -> CommandNode(..root, contents: Some(contents))
    // continue down the path, creating empty command nodes along the way
    [x, ..xs] ->
      CommandNode(
        ..root,
        subcommands: {
          use node <- dict.update(root.subcommands, x)
          node
          |> option.lazy_unwrap(empty_command)
          |> do_add(xs, contents)
        },
      )
  }
}

/// Helper for initializing empty commands
///
fn empty_command() -> CommandNode(a) {
  CommandNode(contents: None, subcommands: dict.new(), group_flags: dict.new())
}

/// Trim each path element and remove any resulting empty strings.
///
fn sanitize_path(path: List(String)) -> List(String) {
  path
  |> list.map(string.trim)
  |> list.filter(is_not_empty)
}

/// Create a Command(a) from a Runner(a)
///
pub fn command(do runner: Runner(a)) -> Command(a) {
  Command(
    do: runner,
    flags: dict.new(),
    description: "",
    unnamed_args: None,
    named_args: [],
  )
}

/// Attach a description to a Command(a)
///
pub fn description(cmd: Command(a), description: String) -> Command(a) {
  Command(..cmd, description: description)
}

/// Specify a specific number of unnamed args that a given command expects
///
pub fn unnamed_args(cmd: Command(a), count: ArgsCount) -> Command(a) {
  Command(..cmd, unnamed_args: Some(count))
}

/// Add a list of named arguments to a Command
/// These named arguments will be matched with the first N arguments passed to the command
/// All named arguments must match for a command to succeed
/// This works in combination with CommandInput.named_args which will contain the matched args in a Dict(String,String)
/// IMPORTANT: Matched named arguments will not be present in CommandInput.args
///
pub fn named_args(cmd: Command(a), args: List(String)) -> Command(a) {
  Command(..cmd, named_args: args)
}

/// Add a `flag.Flag` to a `Command`
///
pub fn flag(
  cmd: Command(a),
  at key: String,
  of flag: flag.FlagBuilder(_),
) -> Command(a) {
  Command(..cmd, flags: dict.insert(cmd.flags, key, flag.build(flag)))
}

/// Add a `flag.Flag to a `Command` when the flag name and builder are bundled as a #(String, flag.FlagBuilder(a)).
///
/// This is merely a convenience function and calls `glint.flag` under the hood.
///
pub fn flag_tuple(
  cmd: Command(a),
  with tup: #(String, flag.FlagBuilder(_)),
) -> Command(a) {
  flag(cmd, tup.0, tup.1)
}

/// Add multiple `Flag`s to a `Command`, note that this function uses `Flag` and not `FlagBuilder(_)`.
/// The user will need to call `flag.build` before providing the flags here.
///
/// It is recommended to call `glint.flag` instead.
///
pub fn flags(cmd: Command(a), with flags: List(#(String, Flag))) -> Command(a) {
  use cmd, #(key, flag) <- list.fold(flags, cmd)
  Command(..cmd, flags: dict.insert(cmd.flags, key, flag))
}

/// Add global flags to the existing command tree
/// This is the equivalent to calling `glint.group_flag` with a path parameter of `[]`.
///
///
@deprecated("use group_flag with a path parameter of [] instead")
pub fn global_flag(
  glint: Glint(a),
  at key: String,
  of flag: flag.FlagBuilder(_),
) -> Glint(a) {
  group_flag(in: glint, at: [], for: key, of: flag)
}

/// Add global flags to the existing command tree.
/// This is the equivalent to calling `glint.group_flag_tuple` with a path parameter of `[]`.
///
@deprecated("use group_flag_tuple with a path parameter of [] instead")
pub fn global_flag_tuple(
  glint: Glint(a),
  with tup: #(String, flag.FlagBuilder(_)),
) -> Glint(a) {
  group_flag(glint, [], tup.0, tup.1)
}

/// Add global flags to the existing command tree.
///
/// Like `glint.flags`, this function requires `Flag`s insead of `FlagBuilder(_)`.
/// This is the equivalent to calling `glint.group_flags` with a path parameter of `[]`.
///
/// Note: use of this function requires calling `flag.build` yourself on any `flag.FlagBuilder`s you wish to convert to `flag.Flag`s
/// It is recommended to use `glint.global_flag` instead.
///
@deprecated("use group_flags with a path parameter of [] instead")
pub fn global_flags(glint: Glint(a), flags: List(#(String, Flag))) -> Glint(a) {
  group_flags(in: glint, at: [], with: flags)
}

/// Add flags for groups of commands.
/// It is recommended to use `glint.group_flag` instead if possible
///
/// The provided flags will be available to all commands at or beyond the provided path
///
/// Note: use of this function requires calling `flag.build` yourself on any `flag.FlagBuilder`s you wish to convert to `flag.Flag`s
///
pub fn group_flags(
  in glint: Glint(a),
  at path: List(String),
  with flags: List(#(String, Flag)),
) -> Glint(a) {
  use glint, flag <- list.fold(flags, glint)
  Glint(
    ..glint,
    cmd: do_group_flag(in: glint.cmd, at: path, for: flag.0, of: flag.1),
  )
}

/// Add a flag for a group of commands.
/// The provided flags will be available to all commands at or beyond the provided path
///
pub fn group_flag(
  in glint: Glint(a),
  at path: List(String),
  for name: String,
  of flag: flag.FlagBuilder(_),
) -> Glint(a) {
  Glint(
    ..glint,
    cmd: do_group_flag(in: glint.cmd, at: path, for: name, of: flag.build(flag)),
  )
}

/// Add a flag for a group of commands.
/// The provided flags will be available to all commands at or beyond the provided path
///
/// This is a convenience function and calls `glint.group_flag` under the hood.
///
pub fn group_flag_tuple(
  in glint: Glint(a),
  at path: List(String),
  of flag: #(String, flag.FlagBuilder(_)),
) -> Glint(a) {
  group_flag(in: glint, at: path, for: flag.0, of: flag.1)
}

/// add a group flag to a command node
/// descend recursively down the command tree to find the node that the flag should be inserted at
///
fn do_group_flag(
  in node: CommandNode(a),
  at path: List(String),
  for name: String,
  of flag: Flag,
) -> CommandNode(a) {
  case path {
    [] ->
      CommandNode(
        ..node,
        group_flags: dict.insert(node.group_flags, name, flag),
      )

    [head, ..tail] ->
      CommandNode(
        ..node,
        subcommands: {
          use node <- dict.update(node.subcommands, head)

          node
          |> option.unwrap(empty_command())
          |> do_group_flag(at: tail, for: name, of: flag)
        },
      )
  }
}

// -- CORE: EXECUTION FUNCTIONS --

/// Determines which command to run and executes it.
///
/// Sets any provided flags if necessary.
///
/// Each value prefixed with `--` is parsed as a flag.
///
/// This function does not print its output and is mainly intended for use within `glint` itself.
/// If you would like to print or handle the output of a command please see the `run_and_handle` function.
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
  do_execute(glint.cmd, glint.config, args, flags, help, [])
}

/// Find which command to execute and run it with computed flags and args
///
fn do_execute(
  cmd: CommandNode(a),
  config: Config,
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
      |> cmd_help(cmd, config)
      |> Help
      |> Ok

    // when there are no more available arguments
    // run the current command
    [] -> execute_root(command_path, config, cmd, [], flags)

    // when there are arguments remaining
    // check if the next one is a subcommand of the current command
    [arg, ..rest] ->
      case dict.get(cmd.subcommands, arg) {
        // subcommand found, continue
        Ok(sub_command) -> {
          let sub_command =
            CommandNode(
              ..sub_command,
              group_flags: dict.merge(cmd.group_flags, sub_command.group_flags),
            )
          do_execute(sub_command, config, rest, flags, help, [
            arg,
            ..command_path
          ])
        }
        // subcommand not found, but help flag has been passed
        // generate and return help message
        _ if help ->
          command_path
          |> cmd_help(cmd, config)
          |> Help
          |> Ok
        // subcommand not found, but help flag has not been passed
        // execute the current command
        _ -> execute_root(command_path, config, cmd, args, flags)
      }
  }
}

fn args_compare(expected: ArgsCount, actual: Int) -> Result(Nil) {
  case expected {
    EqArgs(expected) if actual == expected -> Ok(Nil)
    MinArgs(expected) if actual >= expected -> Ok(Nil)
    EqArgs(expected) -> Error(int.to_string(expected))
    MinArgs(expected) -> Error("at least " <> int.to_string(expected))
  }
  |> result.map_error(fn(err) {
    snag.new(
      "expected: " <> err <> " argument(s), provided: " <> int.to_string(actual),
    )
  })
}

/// Executes the current root command.
///
fn execute_root(
  path: List(String),
  config: Config,
  cmd: CommandNode(a),
  args: List(String),
  flag_inputs: List(String),
) -> CmdResult(a) {
  let res =
    {
      use contents <- option.map(cmd.contents)
      use new_flags <- result.try(list.try_fold(
        over: flag_inputs,
        from: dict.merge(cmd.group_flags, contents.flags),
        with: flag.update_flags,
      ))

      use named_args <- result.try({
        let named = list.zip(contents.named_args, args)
        case list.length(named) == list.length(contents.named_args) {
          True -> Ok(dict.from_list(named))
          False ->
            snag.error(
              "unmatched named arguments: "
              <> {
                contents.named_args
                |> list.drop(list.length(named))
                |> list.map(fn(s) { "'" <> s <> "'" })
                |> string.join(", ")
              },
            )
        }
      })

      let args = list.drop(args, dict.size(named_args))

      use _ <- result.map(case contents.unnamed_args {
        Some(count) ->
          count
          |> args_compare(list.length(args))
          |> snag.context("invalid number of arguments provided")
        None -> Ok(Nil)
      })

      CommandInput(args, new_flags, named_args)
      |> contents.do
      |> Out
    }
    |> option.unwrap(snag.error("command not found"))
    |> snag.context("failed to run command")
    |> result.map_error(fn(err) { #(err, cmd_help(path, cmd, config)) })

  case res {
    Ok(out) -> Ok(out)
    Error(#(snag, help)) ->
      Error(
        snag.pretty_print(snag)
        <> "\nSee the following help text, available via the '--help' flag.\n\n"
        <> help,
      )
  }
}

/// A wrapper for `execute` that prints any errors enountered or the help text if requested.
/// This function ignores any value returned by the command that was run.
/// If you would like to do something with the command output please see the run_and_handle function.
///
pub fn run(from glint: Glint(a), for args: List(String)) -> Nil {
  run_and_handle(from: glint, for: args, with: fn(_) { Nil })
}

/// A wrapper for `execute` that prints any errors enountered or the help text if requested.
/// This function calls the provided handler with the value returned by the command that was run.
///
pub fn run_and_handle(
  from glint: Glint(a),
  for args: List(String),
  with handle: fn(a) -> _,
) -> Nil {
  case execute(glint, args) {
    Error(s) | Ok(Help(s)) -> io.println(s)
    Ok(Out(out)) -> {
      handle(out)
      Nil
    }
  }
}

/// Default pretty help heading colouring
/// mint (r: 182, g: 255, b: 234) colour for usage
/// pink (r: 255, g: 175, b: 243) colour for flags
/// buttercup (r: 252, g: 226, b: 174) colour for subcommands
///
pub fn default_pretty_help() -> PrettyHelp {
  let assert Ok(usage_colour) = colour.from_rgb255(182, 255, 234)
  let assert Ok(flags_colour) = colour.from_rgb255(255, 175, 243)
  let assert Ok(subcommands_colour) = colour.from_rgb255(252, 226, 174)

  PrettyHelp(
    usage: usage_colour,
    flags: flags_colour,
    subcommands: subcommands_colour,
  )
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

/// Function to create the help flag string
/// Exported for testing purposes only
///
pub fn help_flag() -> String {
  flag.prefix <> help_flag_name
}

// -- HELP: FUNCTIONS --

/// generate the help text for a command
fn cmd_help(path: List(String), cmd: CommandNode(a), config: Config) -> String {
  // recreate the path of the current command
  // reverse the path because it is created by prepending each section as do_execute walks down the tree
  path
  |> list.reverse
  |> string.join(" ")
  |> build_command_help_metadata(cmd)
  |> command_help_to_string(config)
}

/// Style heading text with the provided rgb colouring
/// this is only intended for use within glint itself.
///
fn heading_style(heading: String, colour: Colour) -> String {
  heading
  |> ansi.bold
  |> ansi.underline
  |> ansi.italic
  |> ansi.hex(colour.to_rgb_hex(colour))
  |> ansi.reset
}

// ----- HELP -----

// --- HELP: TYPES ---

/// Common metadata for commands and flags
///
type Metadata {
  Metadata(name: String, description: String)
}

/// Help type for flag metadata
///
type FlagHelp {
  FlagHelp(meta: Metadata, type_: String)
}

/// Help type for command metadata
type CommandHelp {
  CommandHelp(
    // Every command has a name and description
    meta: Metadata,
    // A command can have >= 0 flags associated with it
    flags: List(FlagHelp),
    // A command can have >= 0 subcommands associated with it
    subcommands: List(Metadata),
    // A command can have a set number of unnamed arguments
    unnamed_args: Option(ArgsCount),
    // A command can specify named arguments
    named_args: List(String),
  )
}

// -- HELP - FUNCTIONS - BUILDERS --

/// build the help representation for a subtree of commands
///
fn build_command_help_metadata(
  name: String,
  node: CommandNode(_),
) -> CommandHelp {
  let #(description, flags, unnamed_args, named_args) = case node.contents {
    None -> #("", [], None, [])
    Some(cmd) -> #(
      cmd.description,
      build_flags_help(dict.merge(node.group_flags, cmd.flags)),
      cmd.unnamed_args,
      cmd.named_args,
    )
  }

  CommandHelp(
    meta: Metadata(name: name, description: description),
    flags: flags,
    subcommands: build_subcommands_help(node.subcommands),
    unnamed_args: unnamed_args,
    named_args: named_args,
  )
}

/// generate the string representation for the type of a flag
///
fn flag_type_info(flag: Flag) {
  case flag.value {
    flag.I(_) -> "INT"
    flag.B(_) -> "BOOL"
    flag.F(_) -> "FLOAT"
    flag.LF(_) -> "FLOAT_LIST"
    flag.LI(_) -> "INT_LIST"
    flag.LS(_) -> "STRING_LIST"
    flag.S(_) -> "STRING"
  }
}

/// build the help representation for a list of flags
///
fn build_flags_help(flag: FlagMap) -> List(FlagHelp) {
  use acc, name, flag <- dict.fold(flag, [])
  [
    FlagHelp(
      meta: Metadata(name: name, description: flag.description),
      type_: flag_type_info(flag),
    ),
    ..acc
  ]
}

/// build the help representation for a list of subcommands
///
fn build_subcommands_help(
  subcommands: dict.Dict(String, CommandNode(_)),
) -> List(Metadata) {
  use acc, name, cmd <- dict.fold(subcommands, [])
  [
    Metadata(
      name: name,
      description: cmd.contents
        |> option.map(fn(command) { command.description })
        |> option.unwrap(""),
    ),
    ..acc
  ]
}

// -- HELP - FUNCTIONS - STRINGIFIERS --

/// convert a CommandHelp to a styled string
///
fn command_help_to_string(help: CommandHelp, config: Config) -> String {
  // create the header block from the name and description
  let header_items =
    [help.meta.name, help.meta.description]
    |> list.filter(is_not_empty)
    |> string.join("\n")

  // join the resulting help blocks into the final help message
  [
    header_items,
    command_help_to_usage_string(help, config),
    flags_help_to_string(help.flags, config),
    subcommands_help_to_string(help.subcommands, config),
  ]
  |> list.filter(is_not_empty)
  |> string.join("\n\n")
}

// -- HELP - FUNCTIONS - STRINGIFIERS - USAGE --

/// convert a List(FlagHelp) to a list of strings for use in usage text
///
fn flags_help_to_usage_strings(help: List(FlagHelp)) -> List(String) {
  help
  |> list.map(flag_help_to_string)
  |> list.sort(string.compare)
}

/// generate the usage help text for the flags of a command
///
fn flags_help_to_usage_string(help: List(FlagHelp)) -> String {
  use <- bool.guard(help == [], "")

  help
  |> flags_help_to_usage_strings
  |> list.intersperse(" ")
  |> sb.from_strings()
  |> sb.prepend(prefix: "[ ")
  |> sb.append(suffix: " ]")
  |> sb.to_string
}

/// convert an ArgsCount to a string for usage text
///
fn args_count_to_usage_string(count: ArgsCount) -> String {
  case count {
    EqArgs(0) -> ""
    EqArgs(1) -> "[ 1 argument ]"
    EqArgs(n) -> "[ " <> int.to_string(n) <> " arguments ]"
    MinArgs(n) -> "[ " <> int.to_string(n) <> " or more arguments ]"
  }
}

fn args_to_usage_string(
  unnamed: Option(ArgsCount),
  named: List(String),
) -> String {
  let named_args =
    named
    |> list.map(fn(s) { "<" <> s <> ">" })
    |> string.join(" ")
  let unnamed_args =
    option.map(unnamed, args_count_to_usage_string)
    |> option.unwrap("[ ARGS ]")

  case named_args, unnamed_args {
    "", "" -> ""
    "", _ -> unnamed_args
    _, "" -> named_args
    _, _ -> named_args <> " " <> unnamed_args
  }
}

/// convert a CommandHelp to a styled usage block
///
fn command_help_to_usage_string(help: CommandHelp, config: Config) -> String {
  let app_name = case config.name {
    Some(name) if config.as_gleam_module -> "gleam run -m " <> name
    Some(name) -> name
    None -> "gleam run"
  }

  let flags = flags_help_to_usage_string(help.flags)

  let args = args_to_usage_string(help.unnamed_args, help.named_args)

  case config.pretty_help {
    None -> usage_heading
    Some(pretty) -> heading_style(usage_heading, pretty.usage)
  }
  <> "\n\t"
  <> app_name
  <> string_map(help.meta.name, string.append(" ", _))
  <> case args {
    "" -> " "
    _ -> " " <> args <> " "
  }
  <> flags
}

// -- HELP - FUNCTIONS - STRINGIFIERS - FLAGS --

/// generate the usage help string for a command
///
fn flags_help_to_string(help: List(FlagHelp), config: Config) -> String {
  use <- bool.guard(help == [], "")

  case config.pretty_help {
    None -> flags_heading
    Some(pretty) -> heading_style(flags_heading, pretty.flags)
  }
  <> {
    [help_flag_message, ..list.map(help, flag_help_to_string_with_description)]
    |> list.sort(string.compare)
    |> list.map(string.append("\n\t", _))
    |> string.concat
  }
}

/// generate the help text for a flag without a description
///
fn flag_help_to_string(help: FlagHelp) -> String {
  flag.prefix <> help.meta.name <> "=<" <> help.type_ <> ">"
}

/// generate the help text for a flag with a description
///
fn flag_help_to_string_with_description(help: FlagHelp) -> String {
  flag_help_to_string(help) <> "\t\t" <> help.meta.description
}

// -- HELP - FUNCTIONS - STRINGIFIERS - SUBCOMMANDS --

/// generate the styled help text for a list of subcommands
///
fn subcommands_help_to_string(help: List(Metadata), config: Config) -> String {
  use <- bool.guard(help == [], "")

  case config.pretty_help {
    None -> subcommands_heading
    Some(pretty) -> heading_style(subcommands_heading, pretty.subcommands)
  }
  <> {
    help
    |> list.map(subcommand_help_to_string)
    |> list.sort(string.compare)
    |> list.map(string.append("\n\t", _))
    |> string.concat
  }
}

/// generate the help text for a single subcommand given its name and description
///
fn subcommand_help_to_string(help: Metadata) -> String {
  case help.description {
    "" -> help.name
    _ -> help.name <> "\t\t" <> help.description
  }
}

fn string_map(s: String, f: fn(String) -> String) -> String {
  case s {
    "" -> ""
    _ -> f(s)
  }
}
