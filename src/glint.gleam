import gleam/map.{type Map}
import gleam/option.{type Option, None, Some}
import gleam/list
import gleam/io
import gleam/string
import snag.{type Result}
import glint/flag.{type Flag, type Map as FlagMap}
import gleam/string_builder as sb
import gleam_community/ansi
import gleam_community/colour.{type Colour}
import gleam/result
import gleam/function

// --- CONFIGURATION ---

// -- CONFIGURATION: TYPES --

/// Config for glint
///
pub type Config {
  Config(pretty_help: Option(PrettyHelp), name: Option(String))
}

/// PrettyHelp defines the header colours to be used when styling help text
///
pub type PrettyHelp {
  PrettyHelp(usage: Colour, flags: Colour, subcommands: Colour)
}

// -- CONFIGURATION: CONSTANTS --

/// Default config
///
pub const default_config = Config(pretty_help: None, name: None)

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

pub fn with_name(glint: Glint(a), name: String) -> Glint(a) {
  Config(..glint.config, name: Some(name))
  |> with_config(glint, _)
}

// --- CORE ---

// -- CORE: TYPES --

/// Glint container type for config and commands
///
pub opaque type Glint(a) {
  Glint(config: Config, cmd: CommandNode(a), global_flags: FlagMap)
}

/// CommandNode contents
///
pub opaque type Command(a) {
  Command(do: Runner(a), flags: FlagMap, description: String)
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

/// CommandNode tree representation.
///
type CommandNode(a) {
  CommandNode(
    contents: Option(Command(a)),
    subcommands: Map(String, CommandNode(a)),
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
  Result(Out(a))

// -- CORE: BUILDER FUNCTIONS --

/// Creates a new command tree.
///
pub fn new() -> Glint(a) {
  Glint(config: default_config, cmd: empty_command(), global_flags: map.new())
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
          use node <- map.update(root.subcommands, x)
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
  CommandNode(contents: None, subcommands: map.new())
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
  Command(do: runner, flags: map.new(), description: "")
}

/// Attach a description to a Command(a)
///
pub fn description(cmd: Command(a), description: String) -> Command(a) {
  Command(..cmd, description: description)
}

/// add a `flag.Flag` to a `Command`
///
pub fn flag(
  cmd: Command(a),
  at key: String,
  of flag: flag.FlagBuilder(_),
) -> Command(a) {
  Command(..cmd, flags: map.insert(cmd.flags, key, flag.build(flag)))
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

/// Add multiple `Flag`s to a `Command`, note that this function uses `Flag` and not `FlagBuilder(_)`, so the user will need to call `flag.build` before providing the flags here.
/// 
/// It is recommended to call `glint.flag` instead.
///
pub fn flags(cmd: Command(a), with flags: List(#(String, Flag))) -> Command(a) {
  use cmd, #(key, flag) <- list.fold(flags, cmd)
  Command(..cmd, flags: map.insert(cmd.flags, key, flag))
}

/// Add global flags to the existing command tree
///
pub fn global_flag(
  glint: Glint(a),
  at key: String,
  of flag: flag.FlagBuilder(_),
) -> Glint(a) {
  Glint(
    ..glint,
    global_flags: map.insert(glint.global_flags, key, flag.build(flag)),
  )
}

/// Add global flags to the existing command tree.
///
pub fn global_flag_tuple(
  glint: Glint(a),
  with tup: #(String, flag.FlagBuilder(_)),
) -> Glint(a) {
  global_flag(glint, tup.0, tup.1)
}

/// Add global flags to the existing command tree. 
/// 
/// Like `glint.flags`, this function requires `Flag`s insead of `FlagBuilder(_)`.
/// 
/// It is recommended to use `glint.global_flag` instead.
///
pub fn global_flags(glint: Glint(a), flags: List(#(String, Flag))) -> Glint(a) {
  Glint(
    ..glint,
    global_flags: {
      list.fold(
        flags,
        glint.global_flags,
        fn(acc, tup) { map.insert(acc, tup.0, tup.1) },
      )
    },
  )
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
  do_execute(glint.cmd, glint.config, glint.global_flags, args, flags, help, [])
}

/// Find which command to execute and run it with computed flags and args
///
fn do_execute(
  cmd: CommandNode(a),
  config: Config,
  global_flags: FlagMap,
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
      |> cmd_help(cmd, config, global_flags)
      |> Help
      |> Ok

    // when there are no more available arguments
    // run the current command
    [] -> execute_root(cmd, global_flags, [], flags)

    // when there are arguments remaining
    // check if the next one is a subcommand of the current command
    [arg, ..rest] ->
      case map.get(cmd.subcommands, arg) {
        // subcommand found, continue
        Ok(cmd) ->
          do_execute(
            cmd,
            config,
            global_flags,
            rest,
            flags,
            help,
            [arg, ..command_path],
          )
        // subcommand not found, but help flag has been passed
        // generate and return help message
        _ if help ->
          command_path
          |> cmd_help(cmd, config, global_flags)
          |> Help
          |> Ok
        // subcommand not found, but help flag has not been passed
        // execute the current command
        _ -> execute_root(cmd, global_flags, args, flags)
      }
  }
}

/// Executes the current root command.
///
fn execute_root(
  cmd: CommandNode(a),
  global_flags: FlagMap,
  args: List(String),
  flag_inputs: List(String),
) -> CmdResult(a) {
  case cmd.contents {
    Some(contents) -> {
      use new_flags <- result.try(list.try_fold(
        over: flag_inputs,
        from: map.merge(global_flags, contents.flags),
        with: flag.update_flags,
      ))
      CommandInput(args, new_flags)
      |> contents.do
      |> Out
      |> Ok
    }
    None -> snag.error("command not found")
  }
  |> snag.context("failed to run command")
}

/// A wrapper for `execute` that prints any errors enountered or the help text if requested.
/// This function ignores any value returned by the command that was run.
/// If you would like to do something with the command output please see the run_and_handle function.
///
pub fn run(from glint: Glint(a), for args: List(String)) -> Nil {
  run_and_handle(from: glint, for: args, with: function.constant(Nil))
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
    Error(err) ->
      err
      |> snag.pretty_print
      |> io.println
    Ok(Help(help)) -> io.println(help)
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

fn wrap_with_space(s: String) -> String {
  case s {
    "" -> " "
    _ -> " " <> s <> " "
  }
}

/// generate the usage help string for a command
fn usage_help(cmd_name: String, flags: FlagMap, config: Config) -> String {
  let app_name = option.unwrap(config.name, "gleam run")
  let flags =
    flags
    |> map.to_list
    |> list.map(flag.flag_type_help)
    |> list.sort(string.compare)

  let flag_sb = case flags {
    [] -> sb.new()
    _ ->
      flags
      |> list.intersperse(" ")
      |> sb.from_strings()
      |> sb.prepend(prefix: " [ ")
      |> sb.append(suffix: " ]")
  }

  [app_name, wrap_with_space(cmd_name), "[ ARGS ]"]
  |> sb.from_strings
  |> sb.append_builder(flag_sb)
  |> sb.prepend(
    config.pretty_help
    |> option.map(fn(styling) { heading_style(usage_heading, styling.usage) })
    |> option.unwrap(usage_heading) <> "\n\t",
  )
  |> sb.to_string
}

/// generate the help text for a command
fn cmd_help(
  path: List(String),
  cmd: CommandNode(a),
  config: Config,
  global_flags: FlagMap,
) -> String {
  // recreate the path of the current command
  // reverse the path because it is created by prepending each section as do_execute walks down the tree
  let name =
    path
    |> list.reverse
    |> string.join(" ")

  let flags =
    option.map(cmd.contents, fn(contents) { contents.flags })
    |> option.lazy_unwrap(map.new)
    |> map.merge(global_flags, _)

  let flags_help_body =
    config.pretty_help
    |> option.map(fn(p) { heading_style(flags_heading, p.flags) })
    |> option.unwrap(flags_heading) <> "\n\t" <> string.join(
      list.sort([help_flag_message, ..flag.flags_help(flags)], string.compare),
      "\n\t",
    )

  let usage = usage_help(name, flags, config)

  let description =
    cmd.contents
    |> option.map(fn(contents) { contents.description })
    |> option.unwrap("")

  // create the header block from the name and description
  let header_items =
    [name, description]
    |> list.filter(is_not_empty)
    |> string.join("\n")

  // create the subcommands help block
  let subcommands = case subcommands_help(cmd.subcommands) {
    "" -> ""
    subcommands_help_body ->
      config.pretty_help
      |> option.map(fn(p) { heading_style(subcommands_heading, p.subcommands) })
      |> option.unwrap(subcommands_heading) <> "\n\t" <> subcommands_help_body
  }

  // join the resulting help blocks into the final help message
  [header_items, usage, flags_help_body, subcommands]
  |> list.filter(is_not_empty)
  |> string.join("\n\n")
}

// create the help text for subcommands
fn subcommands_help(cmds: Map(String, CommandNode(a))) -> String {
  cmds
  |> map.map_values(subcommand_help)
  |> map.values
  |> list.sort(string.compare)
  |> string.join("\n\t")
}

// generate the help text for a subcommand
fn subcommand_help(name: String, cmd: CommandNode(_)) -> String {
  case cmd.contents {
    None -> name
    Some(contents) -> name <> "\t\t" <> contents.description
  }
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

// -- DEPRECATED: STUBS --

/// DEPRECATED: use `glint.cmd` and related new functions instead to create a Command
/// 
/// Create command stubs to be used in `add_command_from_stub`
///
pub type Stub(a) {
  Stub(
    path: List(String),
    run: Runner(a),
    flags: List(#(String, Flag)),
    description: String,
  )
}

/// Add a command to the root given a stub 
///
@deprecated("use `glint.cmd` and related new functions instead to create a Command")
pub fn add_command_from_stub(to glint: Glint(a), with stub: Stub(a)) -> Glint(a) {
  add(
    to: glint,
    at: stub.path,
    do: command(stub.run)
    |> flags(stub.flags)
    |> description(stub.description),
  )
}
