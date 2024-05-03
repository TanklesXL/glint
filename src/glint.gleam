import gleam
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/string_builder as sb
import gleam_community/ansi
import gleam_community/colour.{type Colour}
import glint/constraint
import snag.{type Snag}

// --- CONFIGURATION ---

// -- CONFIGURATION: TYPES --

/// Config for glint
///
type Config {
  Config(
    pretty_help: Option(PrettyHelp),
    name: Option(String),
    as_module: Bool,
    description: Option(String),
  )
}

/// PrettyHelp defines the header colours to be used when styling help text
///
pub type PrettyHelp {
  PrettyHelp(usage: Colour, flags: Colour, subcommands: Colour)
}

// -- CONFIGURATION: CONSTANTS --

/// default config
///
const default_config = Config(
  pretty_help: None,
  name: None,
  as_module: False,
  description: None,
)

// -- CONFIGURATION: FUNCTIONS --

/// Add the provided config to the existing command tree
///
fn config(glint: Glint(a), config: Config) -> Glint(a) {
  Glint(..glint, config: config)
}

/// Enable custom colours for help text headers
/// For a pre-made colouring use `default_pretty_help()`
///
pub fn pretty_help(glint: Glint(a), pretty: PrettyHelp) -> Glint(a) {
  config(glint, Config(..glint.config, pretty_help: Some(pretty)))
}

/// Give the current glint application a name
///
pub fn with_name(glint: Glint(a), name: String) -> Glint(a) {
  config(glint, Config(..glint.config, name: Some(name)))
}

/// Adjust the generated help text to reflect that the current glint app should be run as a gleam module.
/// Use in conjunction with `glint.with_name` to get usage text output like `gleam run -m <name>`
pub fn as_module(glint: Glint(a)) -> Glint(a) {
  config(glint, Config(..glint.config, as_module: True))
}

// --- CORE ---

// -- CORE: TYPES --

/// Glint container type for config and commands
///
pub opaque type Glint(a) {
  Glint(config: Config, cmd: CommandNode(a))
}

/// Specify the expected number of unnamed arguments with this type and the `glint.unnamed_args` function
///
pub type ArgsCount {
  /// Specifies that a command must accept a specific number of unnamed arguments
  ///
  EqArgs(Int)
  /// Specifies that a command must accept a minimum number of unnamed arguments
  ///
  MinArgs(Int)
}

/// A glint command
///
pub opaque type Command(a) {
  Command(
    do: Runner(a),
    flags: Flags,
    description: String,
    unnamed_args: Option(ArgsCount),
    named_args: List(String),
  )
}

type InternalCommand(a) {
  InternalCommand(
    do: Runner(a),
    flags: Flags,
    unnamed_args: Option(ArgsCount),
    named_args: List(String),
  )
}

pub opaque type NamedArgs {
  NamedArgs(internal: dict.Dict(String, String))
}

/// Functions that execute when glint commands are run.
///
pub type Runner(a) =
  fn(NamedArgs, List(String), Flags) -> a

/// CommandNode tree representation.
///
type CommandNode(a) {
  CommandNode(
    contents: Option(InternalCommand(a)),
    subcommands: dict.Dict(String, CommandNode(a)),
    group_flags: Flags,
    description: String,
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

/// snag.Result type for command execution
///
pub type Result(a) =
  gleam.Result(Out(a), String)

// -- CORE: BUILDER FUNCTIONS --

/// Creates a new command tree.
///
pub fn new() -> Glint(a) {
  Glint(config: default_config, cmd: empty_command())
}

/// Set the help text for a specific command path.
///
/// This function is intended to allow users to set the help text of commands that might not be directly instantiated
/// such as commands with no business logic associated to them but that have subcommands.
///
/// Using this function should almost never be necessary, in most cases you should use `glint.command_help` insstead.
pub fn path_help(
  in glint: Glint(a),
  at path: List(String),
  put description: String,
) -> Glint(a) {
  use node <- update_at(in: glint, at: path)
  CommandNode(..node, description: description)
}

/// Set help text for the application as a whole.
///
/// Help text set with this function wil be printed at the top of the help text for every command.
/// To set help text specifically for the root command please use `glint.command_help` or `glint.path_help([],...)`
///
pub fn global_help(in glint: Glint(a), of description: String) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, description: Some(description)))
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
  do command: Command(a),
) -> Glint(a) {
  use node <- update_at(in: glint, at: path)
  CommandNode(
    ..node,
    description: command.description,
    contents: Some(InternalCommand(
      do: command.do,
      flags: command.flags,
      named_args: command.named_args,
      unnamed_args: command.unnamed_args,
    )),
  )
}

/// Helper for initializing empty commands
///
fn empty_command() -> CommandNode(a) {
  CommandNode(
    contents: None,
    subcommands: dict.new(),
    group_flags: new_flags(),
    description: "",
  )
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
    flags: new_flags(),
    description: "",
    unnamed_args: None,
    named_args: [],
  )
}

/// Attach a helptext description to a Command(a)
///
pub fn command_help(of desc: String, with f: fn() -> Command(a)) -> Command(a) {
  Command(..f(), description: desc)
}

/// Specify a specific number of unnamed args that a given command expects
///
pub fn unnamed_args(
  of args: ArgsCount,
  with f: fn() -> Command(b),
) -> Command(b) {
  Command(..f(), unnamed_args: Some(args))
}

/// Add a list of named arguments to a Command
/// These named arguments will be matched with the first N arguments passed to the command
/// All named arguments must match for a command to succeed
/// This works in combination with CommandInput.named_args which will contain the matched args in a Dict(String,String)
///
/// **IMPORTANT**: Matched named arguments will not be present in the commmand's unnamed args list
///
pub fn named_arg(
  named name: String,
  with f: fn(fn(NamedArgs) -> String) -> Command(a),
) -> Command(a) {
  let cmd = {
    use named_args <- f()
    // we can assert here because the command runner will only execute if the named args match
    let assert Ok(arg) = dict.get(named_args.internal, name)
    arg
  }

  Command(..cmd, named_args: [name, ..cmd.named_args])
}

/// Add a `Flag` to a `Command`
///
pub fn flag(
  of builder: Flag(a),
  with f: fn(fn(Flags) -> snag.Result(a)) -> Command(b),
) -> Command(b) {
  let cmd = f(builder.getter(_, builder.name))
  Command(..cmd, flags: insert(cmd.flags, builder.name, build_flag(builder)))
}

/// Add a flag for a group of commands.
/// The provided flags will be available to all commands at or beyond the provided path
///
pub fn group_flag(
  in glint: Glint(a),
  at path: List(String),
  of flag: Flag(_),
) -> Glint(a) {
  use node <- update_at(in: glint, at: path)
  CommandNode(
    ..node,
    group_flags: insert(node.group_flags, flag.name, build_flag(flag)),
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
@internal
pub fn execute(glint: Glint(a), args: List(String)) -> Result(a) {
  // create help flag to check for
  let help_flag = help_flag()

  // check if help flag is present
  let #(help, args) = case list.pop(args, fn(s) { s == help_flag }) {
    Ok(#(_, args)) -> #(True, args)
    _ -> #(False, args)
  }

  // split flags out from the args list
  let #(flags, args) = list.partition(args, string.starts_with(_, prefix))

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
) -> Result(a) {
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
              group_flags: merge(cmd.group_flags, sub_command.group_flags),
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

fn args_compare(expected: ArgsCount, actual: Int) -> snag.Result(Nil) {
  use err <- result.map_error(case expected {
    EqArgs(expected) if actual == expected -> Ok(Nil)
    MinArgs(expected) if actual >= expected -> Ok(Nil)
    EqArgs(expected) -> Error(int.to_string(expected))
    MinArgs(expected) -> Error("at least " <> int.to_string(expected))
  })
  snag.new(
    "expected: " <> err <> " argument(s), provided: " <> int.to_string(actual),
  )
}

/// Executes the current root command.
///
fn execute_root(
  path: List(String),
  config: Config,
  cmd: CommandNode(a),
  args: List(String),
  flag_inputs: List(String),
) -> Result(a) {
  let res =
    {
      use contents <- option.map(cmd.contents)
      use new_flags <- result.try(list.try_fold(
        over: flag_inputs,
        from: merge(cmd.group_flags, contents.flags),
        with: update_flags,
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

      Out(contents.do(NamedArgs(named_args), args, new_flags))
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

/// default pretty help heading colouring
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
fn help_flag() -> String {
  prefix <> help_flag_name
}

// -- HELP: FUNCTIONS --

/// generate the help text for a command
fn cmd_help(path: List(String), cmd: CommandNode(a), config: Config) -> String {
  // recreate the path of the current command
  // reverse the path because it is created by prepending each section as do_execute walks down the tree
  path
  |> list.reverse
  |> string.join(" ")
  |> build_app_help(config, _, cmd)
  |> app_help_to_string
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
//

type AppHelp {
  AppHelp(config: Config, command: CommandHelp)
}

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
fn build_app_help(config: Config, command_name: String, node: CommandNode(_)) {
  AppHelp(config: config, command: build_command_help(command_name, node))
}

/// build the help representation for a subtree of commands
///
fn build_command_help(name: String, node: CommandNode(_)) -> CommandHelp {
  let #(description, flags, unnamed_args, named_args) = case node.contents {
    None -> #(node.description, [], None, [])
    Some(cmd) -> #(
      node.description,
      build_flags_help(merge(node.group_flags, cmd.flags)),
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
fn flag_type_info(flag: FlagEntry) {
  case flag.value {
    I(_) -> "INT"
    B(_) -> "BOOL"
    F(_) -> "FLOAT"
    LF(_) -> "FLOAT_LIST"
    LI(_) -> "INT_LIST"
    LS(_) -> "STRING_LIST"
    S(_) -> "STRING"
  }
}

/// build the help representation for a list of flags
///
fn build_flags_help(flags: Flags) -> List(FlagHelp) {
  use acc, name, flag <- fold(flags, [])
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
  use acc, name, node <- dict.fold(subcommands, [])
  [Metadata(name: name, description: node.description), ..acc]
}

// -- HELP - FUNCTIONS - STRINGIFIERS --
fn app_help_to_string(help: AppHelp) -> String {
  [
    help.config.description
      |> option.unwrap(""),
    help.command.meta.name
      |> string_map(string.append("Command: ", _)),
    help.command.meta.description,
    command_help_to_usage_string(help.command, help.config),
    flags_help_to_string(help.command.flags, help.config),
    subcommands_help_to_string(help.command.subcommands, help.config),
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

/// convert a CommandHelp to a styled usage block
///
fn command_help_to_usage_string(help: CommandHelp, config: Config) -> String {
  let app_name = case config.name {
    Some(name) if config.as_module -> "gleam run -m " <> name
    Some(name) -> name
    None -> "gleam run"
  }

  let flags = flags_help_to_usage_string(help.flags)
  let subcommands =
    list.map(help.subcommands, fn(sc) { sc.name })
    |> list.sort(string.compare)
    |> string.join(" | ")
    |> string_map(string.append("( ", _))
    |> string_map(string.append(_, " )"))

  let named_args =
    help.named_args
    |> list.map(fn(s) { "<" <> s <> ">" })
    |> string.join(" ")

  let unnamed_args =
    option.map(help.unnamed_args, args_count_to_usage_string)
    |> option.unwrap("[ ARGS ]")

  case config.pretty_help {
    None -> usage_heading
    Some(pretty) -> heading_style(usage_heading, pretty.usage)
  }
  <> "\n\t"
  <> app_name
  <> string_map(help.meta.name, string.append(" ", _))
  <> string_map(subcommands, string.append(" ", _))
  <> string_map(named_args, string.append(" ", _))
  <> string_map(unnamed_args, string.append(" ", _))
  <> string_map(flags, string.append(" ", _))
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
  prefix <> help.meta.name <> "=<" <> help.type_ <> ">"
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

// ----- FLAGS -----

/// FlagEntry inputs must start with this prefix
///
const prefix = "--"

/// The separation character for flag names and their values
const delimiter = "="

/// Supported flag types.
///
type Value {
  /// Boolean flags, to be passed in as `--flag=true` or `--flag=false`.
  /// Can be toggled by omitting the desired value like `--flag`.
  /// Toggling will negate the existing value.
  ///
  B(FlagInternals(Bool))

  /// Int flags, to be passed in as `--flag=1`
  ///
  I(FlagInternals(Int))

  /// List(Int) flags, to be passed in as `--flag=1,2,3`
  ///
  LI(FlagInternals(List(Int)))

  /// Float flags, to be passed in as `--flag=1.0`
  ///
  F(FlagInternals(Float))

  /// List(Float) flags, to be passed in as `--flag=1.0,2.0`
  ///
  LF(FlagInternals(List(Float)))

  /// String flags, to be passed in as `--flag=hello`
  ///
  S(FlagInternals(String))

  /// List(String) flags, to be passed in as `--flag=hello,world`
  ///
  LS(FlagInternals(List(String)))
}

/// A type that facilitates the creation of `FlagEntry`s
///
pub opaque type Flag(a) {
  Flag(
    name: String,
    desc: String,
    parser: Parser(a, Snag),
    value: fn(FlagInternals(a)) -> Value,
    getter: fn(Flags, String) -> snag.Result(a),
    default: Option(a),
  )
}

/// An internal representation of flag contents
///
type FlagInternals(a) {
  FlagInternals(value: Option(a), parser: Parser(a, Snag))
}

// Flag initializers

type Parser(a, b) =
  fn(String) -> gleam.Result(a, b)

/// initialise an int flag
///
pub fn flag_int(named name: String) -> Flag(Int) {
  use input <- new_builder(name, I, get_int_flag)
  input
  |> int.parse
  |> result.replace_error(cannot_parse(input, "int"))
}

/// initialise an int list flag
///
pub fn flag_ints(named name: String) -> Flag(List(Int)) {
  use input <- new_builder(name, LI, get_ints_flag)
  input
  |> string.split(",")
  |> list.try_map(int.parse)
  |> result.replace_error(cannot_parse(input, "int list"))
}

/// initialise a float flag
///
pub fn flag_float(named name: String) -> Flag(Float) {
  use input <- new_builder(name, F, get_floats)
  input
  |> float.parse
  |> result.replace_error(cannot_parse(input, "float"))
}

/// initialise a float list flag
///
pub fn flag_floats(named name: String) -> Flag(List(Float)) {
  use input <- new_builder(name, LF, get_floats_flag)
  input
  |> string.split(",")
  |> list.try_map(float.parse)
  |> result.replace_error(cannot_parse(input, "float list"))
}

/// initialise a string flag
///
pub fn flag_string(named name: String) -> Flag(String) {
  new_builder(name, S, get_string_flag, fn(s) { Ok(s) })
}

/// intitialise a string list flag
///
pub fn flag_strings(named name: String) -> Flag(List(String)) {
  use input <- new_builder(name, LS, get_strings_flag)
  input
  |> string.split(",")
  |> Ok
}

/// initialise a bool flag
///
pub fn flag_bool(named name: String) -> Flag(Bool) {
  use input <- new_builder(name, B, get_bool_flag)
  case string.lowercase(input) {
    "true" | "t" -> Ok(True)
    "false" | "f" -> Ok(False)
    _ -> Error(cannot_parse(input, "bool"))
  }
}

/// initialize custom builders using a Value constructor and a parsing function
///
fn new_builder(
  name: String,
  valuer: fn(FlagInternals(a)) -> Value,
  getter: fn(Flags, String) -> snag.Result(a),
  p: Parser(a, Snag),
) -> Flag(a) {
  Flag(
    name: name,
    desc: "",
    parser: p,
    value: valuer,
    default: None,
    getter: getter,
  )
}

/// convert a Flag(a) into its corresponding FlagEntry representation
///
fn build_flag(fb: Flag(a)) -> FlagEntry {
  FlagEntry(
    value: fb.value(FlagInternals(value: fb.default, parser: fb.parser)),
    description: fb.desc,
  )
}

/// attach a constraint to a flag
///
pub fn constraint(
  builder: Flag(a),
  constraint: constraint.Constraint(a),
) -> Flag(a) {
  Flag(..builder, parser: wrap_with_constraint(builder.parser, constraint))
}

/// attach a Constraint(a) to a Parser(a,Snag)
/// this function should not be used directly unless
fn wrap_with_constraint(
  p: Parser(a, Snag),
  constraint: constraint.Constraint(a),
) -> Parser(a, Snag) {
  fn(input: String) -> snag.Result(a) { attempt(p(input), constraint) }
}

fn attempt(
  val: gleam.Result(a, e),
  f: fn(a) -> gleam.Result(_, e),
) -> gleam.Result(a, e) {
  use a <- result.try(val)
  result.replace(f(a), a)
}

/// FlagEntry data and descriptions
///
type FlagEntry {
  FlagEntry(value: Value, description: String)
}

/// attach a helptext description to a flag
///
pub fn flag_help(for flag: Flag(a), of description: String) -> Flag(a) {
  Flag(..flag, desc: description)
}

/// Set the flag_default value for a flag `Value`
///
pub fn flag_default(for flag: Flag(a), of default: a) -> Flag(a) {
  Flag(..flag, default: Some(default))
}

/// FlagEntry names and their associated values
///
pub opaque type Flags {
  Flags(internal: dict.Dict(String, FlagEntry))
}

fn insert(in flags: Flags, at name: String, insert flag: FlagEntry) -> Flags {
  Flags(dict.insert(flags.internal, name, flag))
}

fn merge(into a: Flags, from b: Flags) -> Flags {
  Flags(internal: dict.merge(a.internal, b.internal))
}

fn fold(flags: Flags, acc: acc, f: fn(acc, String, FlagEntry) -> acc) -> acc {
  dict.fold(flags.internal, acc, f)
}

/// Convert a list of flags to a Flags.
///
fn new_flags() -> Flags {
  Flags(dict.new())
}

/// Updates a flag value, ensuring that the new value can satisfy the required type.
/// Assumes that all flag inputs passed in start with --
/// This function is only intended to be used from glint.execute_root
///
fn update_flags(in flags: Flags, with flag_input: String) -> snag.Result(Flags) {
  let flag_input = string.drop_left(flag_input, string.length(prefix))

  case string.split_once(flag_input, delimiter) {
    Ok(data) -> update_flag_value(flags, data)
    Error(_) -> attempt_toggle_flag(flags, flag_input)
  }
}

fn update_flag_value(
  in flags: Flags,
  with data: #(String, String),
) -> snag.Result(Flags) {
  let #(key, input) = data
  use contents <- result.try(get(flags, key))
  use value <- result.map(
    compute_flag(with: input, given: contents.value)
    |> result.map_error(layer_invalid_flag(_, key)),
  )
  insert(flags, key, FlagEntry(..contents, value: value))
}

fn attempt_toggle_flag(in flags: Flags, at key: String) -> snag.Result(Flags) {
  use contents <- result.try(get(flags, key))
  case contents.value {
    B(FlagInternals(None, ..) as internal) ->
      FlagInternals(..internal, value: Some(True))
      |> B
      |> fn(val) { FlagEntry(..contents, value: val) }
      |> dict.insert(into: flags.internal, for: key)
      |> Flags
      |> Ok
    B(FlagInternals(Some(val), ..) as internal) ->
      FlagInternals(..internal, value: Some(!val))
      |> B
      |> fn(val) { FlagEntry(..contents, value: val) }
      |> dict.insert(into: flags.internal, for: key)
      |> Flags
      |> Ok
    _ -> Error(no_value_flag_err(key))
  }
}

fn access_type_error(flag_type) {
  snag.error("cannot access flag as " <> flag_type)
}

fn flag_not_provided_error() {
  snag.error("no value provided")
}

fn construct_value(
  input: String,
  internal: FlagInternals(a),
  constructor: fn(FlagInternals(a)) -> Value,
) -> snag.Result(Value) {
  use val <- result.map(internal.parser(input))
  constructor(FlagInternals(..internal, value: Some(val)))
}

/// Computes the new flag value given the input and the expected flag type
///
fn compute_flag(with input: String, given current: Value) -> snag.Result(Value) {
  input
  |> case current {
    I(internal) -> construct_value(_, internal, I)
    LI(internal) -> construct_value(_, internal, LI)
    F(internal) -> construct_value(_, internal, F)
    LF(internal) -> construct_value(_, internal, LF)
    S(internal) -> construct_value(_, internal, S)
    LS(internal) -> construct_value(_, internal, LS)
    B(internal) -> construct_value(_, internal, B)
  }
  |> snag.context("failed to compute value for flag")
}

// Error creation and manipulation functions
fn layer_invalid_flag(err: Snag, flag: String) -> Snag {
  snag.layer(err, "invalid flag '" <> flag <> "'")
}

fn no_value_flag_err(flag_input: String) -> Snag {
  { "flag '" <> flag_input <> "' has no assigned value" }
  |> snag.new()
  |> layer_invalid_flag(flag_input)
}

fn undefined_flag_err(key: String) -> Snag {
  "flag provided but not defined"
  |> snag.new()
  |> layer_invalid_flag(key)
}

fn cannot_parse(with value: String, is kind: String) -> Snag {
  { "cannot parse value '" <> value <> "' as " <> kind }
  |> snag.new()
}

// -- FLAG ACCESS FUNCTIONS --

/// Access the contents for the associated flag
///
fn get(flags: Flags, name: String) -> snag.Result(FlagEntry) {
  dict.get(flags.internal, name)
  |> result.replace_error(undefined_flag_err(name))
}

fn get_value(
  from flags: Flags,
  at key: String,
  expecting kind: fn(FlagEntry) -> snag.Result(a),
) -> snag.Result(a) {
  get(flags, key)
  |> result.try(kind)
  |> snag.context("failed to retrieve value for flag '" <> key <> "'")
}

/// Gets the value for the associated flag.
///
/// This function should only ever be used when fetching flags set at the group level.
/// For local flags please use the getter functions provided when calling `glint.flag`.
///
pub fn get_flag(from flags: Flags, for flag: Flag(a)) -> snag.Result(a) {
  flag.getter(flags, flag.name)
}

/// Gets the current value for the associated int flag
///
fn get_int_flag(from flags: Flags, for name: String) -> snag.Result(Int) {
  use flag <- get_value(flags, name)
  case flag.value {
    I(FlagInternals(value: Some(val), ..)) -> Ok(val)
    I(FlagInternals(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("int")
  }
}

/// Gets the current value for the associated ints flag
///
fn get_ints_flag(from flags: Flags, for name: String) -> snag.Result(List(Int)) {
  use flag <- get_value(flags, name)
  case flag.value {
    LI(FlagInternals(value: Some(val), ..)) -> Ok(val)
    LI(FlagInternals(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("int list")
  }
}

/// Gets the current value for the associated bool flag
///
fn get_bool_flag(from flags: Flags, for name: String) -> snag.Result(Bool) {
  use flag <- get_value(flags, name)
  case flag.value {
    B(FlagInternals(Some(val), ..)) -> Ok(val)
    B(FlagInternals(None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("bool")
  }
}

/// Gets the current value for the associated string flag
///
fn get_string_flag(from flags: Flags, for name: String) -> snag.Result(String) {
  use flag <- get_value(flags, name)
  case flag.value {
    S(FlagInternals(value: Some(val), ..)) -> Ok(val)
    S(FlagInternals(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("string")
  }
}

/// Gets the current value for the associated strings flag
///
fn get_strings_flag(
  from flags: Flags,
  for name: String,
) -> snag.Result(List(String)) {
  use flag <- get_value(flags, name)
  case flag.value {
    LS(FlagInternals(value: Some(val), ..)) -> Ok(val)
    LS(FlagInternals(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("string list")
  }
}

/// Gets the current value for the associated float flag
///
fn get_floats(from flags: Flags, for name: String) -> snag.Result(Float) {
  use flag <- get_value(flags, name)
  case flag.value {
    F(FlagInternals(value: Some(val), ..)) -> Ok(val)
    F(FlagInternals(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("float")
  }
}

/// Gets the current value for the associated float flag
///
fn get_floats_flag(
  from flags: Flags,
  for name: String,
) -> snag.Result(List(Float)) {
  use flag <- get_value(flags, name)
  case flag.value {
    LF(FlagInternals(value: Some(val), ..)) -> Ok(val)
    LF(FlagInternals(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("float list")
  }
}

// traverses a Glint(a) tree for the provided path
// executes the provided function on the terminal node
//
fn update_at(
  in glint: Glint(a),
  at path: List(String),
  do f: fn(CommandNode(a)) -> CommandNode(a),
) -> Glint(a) {
  Glint(
    ..glint,
    cmd: do_update_at(through: glint.cmd, at: sanitize_path(path), do: f),
  )
}

fn do_update_at(
  through node: CommandNode(a),
  at path: List(String),
  do f: fn(CommandNode(a)) -> CommandNode(a),
) -> CommandNode(a) {
  case path {
    [] -> f(node)
    [next, ..rest] -> {
      CommandNode(
        ..node,
        subcommands: {
          use found <- dict.update(node.subcommands, next)
          found
          |> option.lazy_unwrap(empty_command)
          |> do_update_at(rest, f)
        },
      )
    }
  }
}
