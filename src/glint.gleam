import gleam/dict
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam_community/ansi
import glint/constraint
import glint/internal/help
import glint/internal/parameter
import glint/internal/parse
import snag.{type Snag}

// --- CONFIGURATION ---

// -- CONFIGURATION: TYPES --

/// Config for glint
///
type Config {
  Config(
    header_format: HeaderFormat,
    name: Option(String),
    as_module: Bool,
    description: Option(String),
    exit: Bool,
    indent_width: Int,
    max_output_width: Int,
    min_first_column_width: Int,
    column_gap: Int,
  )
}

type HeaderFormat {
  HeaderFormat(
    usage: fn(String) -> String,
    named_args: fn(String) -> String,
    flags: fn(String) -> String,
    subcommands: fn(String) -> String,
  )
}

// -- CONFIGURATION: CONSTANTS --

/// default config
///
const default_config = Config(
  header_format: HeaderFormat(
    function.identity,
    function.identity,
    function.identity,
    function.identity,
  ),
  name: None,
  as_module: False,
  description: None,
  exit: True,
  indent_width: 4,
  max_output_width: 80,
  min_first_column_width: 20,
  column_gap: 2,
)

// -- CONFIGURATION: FUNCTIONS --

/// Set the style for each of the glint helptext headers (usage, flags, subcommands).
///
/// This function will likely be used with colouring functions from [gleam_community/ansi](https://hexdocs.pm/gleam_community_ansi/).
///
/// When setting your own header styles, you may want to leverage the default formatting as provided by [`glint.default_header_format`](#default_header_format)
/// which can be composed witth other functions from [gleam_community/ansi](https://hexdocs.pm/gleam_community_ansi/)..
///
///
/// Example:
///
/// ```gleam
/// glint.with_header_style(
///   glint,
///   usage: fn(s) { s |> glint.default_header_format |> ansi.cyan },
///   flags: fn(s) { s |> glint.default_header_format |> ansi.magenta },
///   subcommands: fn(s) { s |> glint.default_header_format |> ansi.yellow },
/// )
/// ```
pub fn with_header_style(
  glint: Glint(a),
  usage usage: fn(String) -> String,
  named_args named_args: fn(String) -> String,
  flags flags: fn(String) -> String,
  subcommands subcommands: fn(String) -> String,
) -> Glint(a) {
  let header_format = HeaderFormat(usage:, named_args:, flags:, subcommands:)
  let config = Config(..glint.config, header_format:)
  Glint(..glint, config:)
}

/// This function sets the glint help text header styles using glint's defaults.
///
/// Each help text header is formatted as bold, italic and underline (see [`glint.default_header_format`](#default_header_format)).
///
/// The default colours are ANSI compatible  as follows:
/// - usage: cyan
/// - flags: pink
/// - subcommands: yellow
///
pub fn with_default_header_style(glint: Glint(a)) -> Glint(a) {
  with_header_style(
    glint,
    usage: fn(s) { s |> default_header_format |> ansi.cyan },
    named_args: fn(s) { s |> default_header_format |> ansi.blue },
    flags: fn(s) { s |> default_header_format |> ansi.pink },
    subcommands: fn(s) { s |> default_header_format |> ansi.yellow },
  )
}

/// Style heading text as bold, underlined and italic.
///
/// This function can be combined with other functions from [gleam_community/ansi](https://hexdocs.pm/gleam_community_ansi/)
///
pub fn default_header_format(heading: String) -> String {
  heading
  |> ansi.bold
  |> ansi.underline
  |> ansi.italic
}

/// Give the current glint application a name.
///
/// The name specified here is used when generating help text for the current glint instance.
///
pub fn with_name(glint: Glint(a), name: String) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, name: Some(name)))
}

/// By default, Glint exits with error status 1 when an error is encountered (eg. invalid flag or command not found)
///
/// Calling this function disables that feature.
///
pub fn without_exit(glint: Glint(a)) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, exit: False))
}

/// Adjust the generated help text to reflect that the current glint app should be run as a gleam module.
///
/// Use in conjunction with [`glint.with_name`](#with_name) to get usage text output like `gleam run -m <name>`
///
pub fn as_module(glint: Glint(a)) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, as_module: True))
}

/// Adjusts the indent width used to indent content under the usage, flags,
/// and subcommands headings in the help output.
///
/// Default: 4.
///
pub fn with_indent_width(glint: Glint(a), indent_width: Int) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, indent_width:))
}

/// Adjusts the output width at which help text will wrap onto a new line.
///
/// Default: 80.
///
pub fn with_max_output_width(glint: Glint(a), max_output_width: Int) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, max_output_width:))
}

/// Adjusts the minimum width of the column containing flag and command names in the help output.
///
/// Default: 20.
///
pub fn with_min_first_column_width(
  glint: Glint(a),
  min_first_column_width: Int,
) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, min_first_column_width:))
}

/// Adjusts the size of the gap between columns in the help output.
///
/// Default: 2.
///
pub fn with_column_gap(glint: Glint(a), column_gap: Int) -> Glint(a) {
  Glint(..glint, config: Config(..glint.config, column_gap:))
}

// --- CORE ---

// -- CORE: TYPES --

/// A container type for config and commands.
///
/// This will be the main interaction point when setting up glint.
/// To create a new one use [`glint.new`](#new).
///
pub opaque type Glint(a) {
  Glint(config: Config, cmd: CommandNode(a))
}

/// Specify the expected number of unnamed arguments with this type and the [`glint.unnamed_args`](#unnamed_args) function
///
pub type ArgsCount {
  /// Specifies that a command must accept a specific number of unnamed arguments
  ///
  EqArgs(Int)
  /// Specifies that a command must accept a minimum number of unnamed arguments
  ///
  MinArgs(Int)
}

/// The type representing a glint command.
///
/// To create a new command, use the [`glint.command`](#command) function.
///
pub opaque type Command(a) {
  Command(
    do: Runner(a),
    flags: Flags,
    description: String,
    unnamed_args: Option(ArgsCount),
    named_args: List(Parameters(NamedArg)),
  )
}

/// A container for named arguments available to commands at runtime.
///
pub opaque type NamedArgs {
  NamedArgs(internal: dict.Dict(String, Parameters(NamedArg)))
}

/// Functions that execute when glint commands are run.
///
pub type Runner(a) =
  fn(NamedArgs, List(String), Flags) -> a

/// CommandNode tree representation.
///
type CommandNode(a) {
  CommandNode(
    contents: Option(Command(a)),
    subcommands: dict.Dict(String, CommandNode(a)),
    group_flags: Flags,
    description: String,
  )
}

/// Ok type for command execution
///
@internal
pub type Out(a) {
  /// Container for the command return value
  Out(a)
  /// Container for the generated help string
  Help(String)
}

// -- CORE: BUILDER FUNCTIONS --

/// Create a new glint instance.
///
pub fn new() -> Glint(a) {
  Glint(config: default_config, cmd: empty_command())
}

/// Set the help text for a specific command path.
///
/// This function is intended to allow users to set the help text of commands that might not be directly instantiated,
/// such as commands with no business logic associated to them but that have subcommands.
///
/// Using this function should almost never be necessary, in most cases you should use [`glint.command_help`](#command_help) insstead.
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
/// To set help text specifically for the root command please use [`glint.command_help`](#command_help) or [`glint.path_help([],...)`](#path_help)
///
/// This function allows for user-supplied newlines in long text strings. Individual newline characters are instead converted to spaces.
/// This is useful for developers to format their help text in a more readable way in the source code.
///
/// For formatted text to appear on a new line, use 2 newline characters.
/// For formatted text to appear in a new paragraph, use 3 newline characters.
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
/// ```gleam
/// glint.new()
/// |> glint.add(at: [], do: root_command())
/// |> glint.add(at: ["subcommand"], do: subcommand())
/// ...
/// ```
///
pub fn add(
  to glint: Glint(a),
  at path: List(String),
  do command: Command(a),
) -> Glint(a) {
  use node <- update_at(in: glint, at: path)
  CommandNode(..node, description: command.description, contents: Some(command))
}

/// Helper for initializing empty commands
///
fn empty_command() -> CommandNode(a) {
  CommandNode(
    contents: None,
    subcommands: dict.new(),
    group_flags: Flags(dict.new()),
    description: "",
  )
}

/// Trim each path element and remove any resulting empty strings.
///
fn sanitize_path(path: List(String)) -> List(String) {
  path
  |> list.map(string.trim)
  |> list.filter(fn(s) { s != "" })
}

/// Create a [Command(a)](#Command) from a [Runner(a)](#Runner).
///
/// ### Example:
///
/// ```gleam
/// use <- glint.command_help("Some awesome help text")
/// use named_arg <- glint.named_arg("some_arg")
/// use <- glint.unnamed_args(glint.EqArgs(0))
/// ...
/// use named, unnamed, flags <- glint.command()
/// let my_arg = named_arg(named)
/// ...
/// ```
pub fn command(do runner: Runner(a)) -> Command(a) {
  Command(
    do: runner,
    flags: Flags(dict.new()),
    description: "",
    unnamed_args: None,
    named_args: [],
  )
}

/// Attach a helptext description to a [`Command(a)`](#Command)
///
/// This function allows for user-supplied newlines in long text strings. Individual newline characters are instead converted to spaces.
/// This is useful for developers to format their help text in a more readable way in the source code.
///
/// For formatted text to appear on a new line, use 2 newline characters.
/// For formatted text to appear in a new paragraph, use 3 newline characters.
///
pub fn command_help(of desc: String, with f: fn() -> Command(a)) -> Command(a) {
  Command(..f(), description: desc)
}

/// Specify a specific number of unnamed args that a given command expects.
///
/// Use in conjunction with [`glint.ArgsCount`](#ArgsCount) to specify either a minimum or a specific number of args.
///
/// ### Example:
///
/// ```gleam
/// ...
/// // for a command that accets only 1 unnamed argument:
/// use <- glint.unnamed_args(glint.EqArgs(1))
/// ...
/// named, unnamed, flags <- glint.command()
/// let assert Ok([arg]) = unnamed
/// ```
///
pub fn unnamed_args(
  of count: ArgsCount,
  with f: fn() -> Command(b),
) -> Command(b) {
  Command(..f(), unnamed_args: Some(count))
}

/// Add a flag for a group of commands.
/// The provided flags will be available to all commands at or beyond the provided path
///
pub fn group_flag(
  in glint: Glint(a),
  at path: List(String),
  of flag: Parameter(_, Flag),
) -> Glint(a) {
  use node <- update_at(in: glint, at: path)
  CommandNode(
    ..node,
    group_flags: Flags(dict.insert(
      node.group_flags.internal,
      flag.internal.name,
      flag.constructor(flag),
    )),
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
pub fn execute(glint: Glint(a), args: List(String)) -> Result(Out(a), String) {
  // create help flag to check for
  let help_flag = flag_prefix <> help.help_flag.meta.name

  // check if help flag is present
  let #(help, args) = case list.pop(args, fn(s) { s == help_flag }) {
    Ok(#(_, args)) -> #(True, args)
    _ -> #(False, args)
  }

  // split flags out from the args list
  let #(flags, args) = list.partition(args, string.starts_with(_, flag_prefix))

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
) -> Result(Out(a), String) {
  case args {
    // when there are no more available arguments
    // and help flag has been passed, generate help message
    [] if help -> Ok(Help(cmd_help(command_path, cmd, config)))

    // when there are no more available arguments
    // run the current command
    [] -> execute_root(command_path, config, cmd, [], flags) |> result.map(Out)

    // when there are arguments remaining
    // check if the next one is a subcommand of the current command
    [arg, ..rest] ->
      case dict.get(cmd.subcommands, arg) {
        // subcommand found, continue
        Ok(sub_command) ->
          CommandNode(
            ..sub_command,
            group_flags: Flags(dict.merge(
              cmd.group_flags.internal,
              sub_command.group_flags.internal,
            )),
          )
          |> do_execute(config, rest, flags, help, [arg, ..command_path])

        // subcommand not found, but help flag has been passed
        // generate and return help message
        _ if help -> Ok(Help(cmd_help(command_path, cmd, config)))

        // subcommand not found, but help flag has not been passed
        // execute the current command
        _ ->
          execute_root(command_path, config, cmd, args, flags)
          |> result.map(Out)
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
) -> Result(a, String) {
  {
    // check if the command can actually be executed
    use contents <- result.try(option.to_result(
      cmd.contents,
      snag.new("command not found"),
    ))

    // merge flags and parse flag inputs
    use new_flags <- result.try(list.try_fold(
      over: flag_inputs,
      from: dict.merge(cmd.group_flags.internal, contents.flags.internal),
      with: update_flags,
    ))

    // get named arguments
    use named_args <- result.try({
      let named = list.zip(contents.named_args, args)
      case list.length(named) == list.length(contents.named_args) {
        True -> {
          use acc, #(param, input) <- list.try_fold(named, dict.new())
          use #(param, name) <- result.try(
            parse_parameter(param, input)
            |> snag.context(
              "invalid named argument '" <> parameter_name(param) <> "'",
            ),
          )
          Ok(dict.insert(acc, name, param))
        }

        False ->
          snag.error(
            "unmatched named arguments: "
            <> {
              contents.named_args
              |> list.drop(list.length(named))
              |> list.map(fn(s) { "'" <> parameter_name(s) <> "'" })
              |> string.join(", ")
            },
          )
      }
    })

    // get unnamed arguments
    let args = list.drop(args, dict.size(named_args))

    // validate unnamed argument quantity
    use _ <- result.map(case contents.unnamed_args {
      Some(count) ->
        count
        |> args_compare(list.length(args))
        |> snag.context("invalid number of unnamed arguments provided")
      None -> Ok(Nil)
    })

    // execute the command
    contents.do(NamedArgs(named_args), args, Flags(new_flags))
  }
  |> result.map_error(fn(err) {
    err
    |> snag.layer("failed to run command")
    |> snag.pretty_print
    <> "\nSee the following help text, available via the '--help' flag.\n\n"
    <> cmd_help(path, cmd, config)
  })
}

/// Run a glint app and print any errors enountered, or the help text if requested.
/// This function ignores any value returned by the command that was run.
/// If you would like to do handle the command output please see the [`glint.run_and_handle`](#run_and_handle) function.
///
/// IMPORTANT: This function exits with code 1 if an error was encountered.
/// If this behaviour is not desired please disable it with [`glint.without_exit`](#without_exit)
///
pub fn run(from glint: Glint(a), for args: List(String)) -> Nil {
  run_and_handle(from: glint, for: args, with: fn(_) { Nil })
}

/// Run a glint app with a custom handler for command output.
/// This function prints any errors enountered or the help text if requested.
///
/// IMPORTANT: This function exits with code 1 if an error was encountered.
/// If this behaviour is not desired please disable it with [`glint.without_exit`](#without_exit)
///
pub fn run_and_handle(
  from glint: Glint(a),
  for args: List(String),
  with handle: fn(a) -> _,
) -> Nil {
  case execute(glint, args) {
    Error(s) -> {
      io.println(s)
      case glint.config.exit {
        True -> exit(1)
        False -> Nil
      }
    }
    Ok(Help(s)) -> io.println(s)
    Ok(Out(out)) -> {
      handle(out)
      Nil
    }
  }
}

// -- HELP: FUNCTIONS --

/// generate the help text for a command
fn cmd_help(path: List(String), cmd: CommandNode(a), config: Config) -> String {
  // recreate the path of the current command
  // reverse the path because it is created by prepending each section as do_execute walks down the tree
  path
  |> list.reverse
  |> string.join(" ")
  |> build_command_help(cmd)
  |> help.command_help_to_string(build_help_config(config))
}

// -- HELP - FUNCTIONS - BUILDERS --
fn build_help_config(config: Config) -> help.Config {
  help.Config(
    name: config.name,
    usage_colour: config.header_format.usage,
    named_args_colour: config.header_format.named_args,
    flags_colour: config.header_format.flags,
    subcommands_colour: config.header_format.subcommands,
    as_module: config.as_module,
    description: config.description,
    indent_width: config.indent_width,
    max_output_width: config.max_output_width,
    min_first_column_width: config.min_first_column_width,
    column_gap: config.column_gap,
    flag_prefix: flag_prefix,
    flag_delimiter: flag_delimiter,
  )
}

/// build the help representation for a subtree of commands
///
fn build_command_help(name: String, node: CommandNode(_)) -> help.Command {
  let #(description, flags, unnamed_args, named_args) =
    node.contents
    |> option.map(fn(cmd) {
      #(
        node.description,
        build_flags_help(dict.merge(
          node.group_flags.internal,
          cmd.flags.internal,
        )),
        cmd.unnamed_args,
        cmd.named_args |> build_named_args_help,
      )
    })
    |> option.unwrap(#(node.description, [], None, []))

  help.Command(
    meta: help.Metadata(name: name, description: description),
    flags: flags,
    subcommands: build_subcommands_help(node.subcommands),
    unnamed_args: {
      use args <- option.map(unnamed_args)
      case args {
        EqArgs(n) -> help.EqArgs(n)
        MinArgs(n) -> help.MinArgs(n)
      }
    },
    named_args: named_args,
  )
}

/// generate the string representation for the type of a flag
///
fn parameters_type_info(p: Parameters(a)) {
  case p {
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
fn build_flags_help(
  params: dict.Dict(String, Parameters(Flag)),
) -> List(help.Parameter) {
  use acc, name, flag <- dict.fold(params, [])
  [
    help.Parameter(
      meta: help.Metadata(name: name, description: parameter_help(flag)),
      type_: parameters_type_info(flag),
    ),
    ..acc
  ]
}

/// build the help representation for a list of flags
///
fn build_named_args_help(
  params: List(Parameters(NamedArg)),
) -> List(help.Parameter) {
  use param <- list.map(params)
  help.Parameter(
    meta: help.Metadata(
      name: parameter_name(param),
      description: parameter_help(param),
    ),
    type_: parameters_type_info(param),
  )
}

/// build the help representation for a list of subcommands
///
fn build_subcommands_help(
  subcommands: dict.Dict(String, CommandNode(_)),
) -> List(help.Metadata) {
  use acc, name, node <- dict.fold(subcommands, [])
  [help.Metadata(name: name, description: node.description), ..acc]
}

// ----- FLAGS -----

/// FlagEntry inputs must start with this prefix
///
const flag_prefix = "--"

/// The separation character for flag names and their values
const flag_delimiter = "="

/// Flags passed as input to a command.
///
pub opaque type Flags {
  Flags(internal: dict.Dict(String, Parameters(Flag)))
}

/// Updates a flag value, ensuring that the new value can satisfy the required type.
/// Assumes that all flag inputs passed in start with --
/// This function is only intended to be used from glint.execute_root
///
fn update_flags(
  in flags: dict.Dict(String, Parameters(Flag)),
  with flag_input: String,
) -> Result(dict.Dict(String, Parameters(Flag)), Snag) {
  let flag_input = string.drop_left(flag_input, string.length(flag_prefix))

  case string.split_once(flag_input, flag_delimiter) {
    Ok(data) -> update_flag_value(flags, data)
    Error(_) -> attempt_toggle_flag(flags, flag_input)
  }
}

fn update_flag_value(
  in flags: dict.Dict(String, Parameters(Flag)),
  with data: #(String, String),
) -> Result(dict.Dict(String, Parameters(Flag)), Snag) {
  let #(key, input) = data
  use contents <- result.try(
    dict.get(flags, key)
    |> result.replace_error(undefined_flag_err(key)),
  )
  use #(value, name) <- result.map(
    parse_parameter(contents, input)
    |> snag.context("invalid value for flag '" <> key <> "'"),
  )
  dict.insert(flags, name, value)
}

fn attempt_toggle_flag(
  in flags: dict.Dict(String, Parameters(_)),
  at key: String,
) -> Result(dict.Dict(String, Parameters(_)), Snag) {
  use contents <- result.try(
    dict.get(flags, key) |> result.replace_error(undefined_flag_err(key)),
  )
  case contents {
    B(
      Parameter(
        internal: parameter.Parameter(
          value: None,
          ..,
        ) as internal,
        ..,
      ) as param,
    ) ->
      Parameter(
        ..param,
        internal: parameter.Parameter(..internal, value: Some(True)),
      )
      |> B
      |> dict.insert(into: flags, for: key)
      |> Ok
    B(
      Parameter(
        internal: parameter.Parameter(
          value: Some(val),
          ..,
        ) as internal,
        ..,
      ) as param,
    ) ->
      Parameter(
        ..param,
        internal: parameter.Parameter(..internal, value: Some(!val)),
      )
      |> B
      |> dict.insert(into: flags, for: key)
      |> Ok
    _ -> Error(cannot_toggle_flag_error(key))
  }
}

// Error creation and manipulation functions
fn layer_invalid_flag(err: Snag, flag: String) -> Snag {
  snag.layer(err, "invalid flag '" <> flag <> "'")
}

fn cannot_toggle_flag_error(flag_input: String) -> Snag {
  snag.new("flag '" <> flag_input <> "' cannot be toggled")
  |> layer_invalid_flag(flag_input)
}

fn undefined_flag_err(key: String) -> Snag {
  snag.new("flag provided but not defined")
  |> layer_invalid_flag(key)
}

// -- FLAG ACCESS FUNCTIONS --

/// Gets the value for the associated flag.
///
/// In most cases you should use the getter functions provided when calling [`glint.flag`](#flag).
///
pub fn get_flag(
  from flags: Flags,
  for flag: Parameter(a, Flag),
) -> Result(a, Nil) {
  flag.getter(flags.internal)
}

/// Gets the value for the associated named argument.
///
/// In most cases you should use the getter functions provided when calling [`glint.named_arg`](#named_arg).
///
pub fn get_named_arg(
  from named_args: NamedArgs,
  for named_arg: Parameter(a, NamedArg),
) -> a {
  let assert Ok(a) = named_arg.getter(named_args.internal)
  a
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
          use found <- dict.upsert(node.subcommands, next)
          found
          |> option.lazy_unwrap(empty_command)
          |> do_update_at(rest, f)
        },
      )
    }
  }
}

@external(erlang, "erlang", "halt")
@external(javascript, "node:process", "exit")
fn exit(status: Int) -> Nil

pub type NamedArg

pub type Flag

fn new_parameter(
  name: String,
  constructor: fn(Parameter(a, b)) -> Parameters(b),
  parse: fn(String) -> Result(a, Snag),
  getter: fn(dict.Dict(String, Parameters(b))) -> Result(a, Nil),
) -> Parameter(a, b) {
  Parameter(
    internal: parameter.Parameter(
      name: name,
      description: "",
      parser: parse,
      value: option.None,
    ),
    constructor: constructor,
    getter: getter,
  )
}

/// Attach a constraint to a parameter.
///
/// As constraints are just functions, this works well as both part of a pipeline or with `use`.
///
///
/// ### Pipe:
///
/// ```gleam
/// glint.int("my_flag")
/// |> glint.param_help("An awesome flag")
/// |> glint.constraint(fn(i) {
///   case i < 0 {
///     True -> snag.error("must be greater than 0")
///     False -> Ok(i)
///   }})
/// ```
///
/// ### Use:
///
/// ```gleam
/// use i <- glint.constraint(
///   glint.int("my_flag")
///   |> glint.param_help("An awesome flag")
/// )
/// case i < 0 {
///   True -> snag.error("must be greater than 0")
///   False -> Ok(i)
/// }
/// ```
///
pub fn constraint(
  p: Parameter(a, b),
  c: constraint.Constraint(a),
) -> Parameter(a, b) {
  Parameter(..p, internal: parameter.add_constraint(p.internal, c))
}

/// Set the default value for a parameter.
///
/// ### Example:
///
/// ```gleam
/// glint.int("awesome_flag")
/// |> glint.default(1)
/// ```
///
pub fn default(p: Parameter(a, Flag), d: a) {
  Parameter(
    ..p,
    internal: parameter.Parameter(..p.internal, value: option.Some(d)),
  )
}

/// Attach a help text description to a flag.
///
/// This function allows for user-supplied newlines in long text strings. Individual newline characters are instead converted to spaces.
/// This is useful for developers to format their help text in a more readable way in the source code.
///
/// For formatted text to appear on a new line, use 2 newline characters.
/// For formatted text to appear in a new paragraph, use 3 newline characters.
///
/// ### Example:
///
/// ```gleam
/// glint.int("awesome_flag")
/// |> glint.param_help("Some great text!")
/// ```
///
pub fn param_help(p: Parameter(a, b), description: String) {
  Parameter(..p, internal: parameter.Parameter(..p.internal, description:))
}

pub fn int(name: String) -> Parameter(Int, _) {
  use params <- new_parameter(name, I, fn(s) {
    s
    |> parse.int
    |> result.map_error(fn(e) { e |> parse.error_to_string |> snag.new })
  })
  use v <- result.try(dict.get(params, name))
  case v {
    I(param) -> option.to_result(param.internal.value, Nil)
    _ -> Error(Nil)
  }
}

pub fn ints(name: String) -> Parameter(List(Int), _) {
  use params <- new_parameter(name, LI, fn(s) {
    s
    |> parse.ints
    |> result.map_error(fn(e) { e |> parse.error_to_string |> snag.new })
  })
  use v <- result.try(dict.get(params, name))
  case v {
    LI(param) -> option.to_result(param.internal.value, Nil)
    _ -> Error(Nil)
  }
}

pub fn string(name: String) -> Parameter(String, _) {
  use params <- new_parameter(name, S, fn(s) {
    s
    |> parse.string
    |> result.map_error(fn(e) { e |> parse.error_to_string |> snag.new })
  })
  use v <- result.try(dict.get(params, name))
  case v {
    S(param) -> option.to_result(param.internal.value, Nil)
    _ -> Error(Nil)
  }
}

pub fn strings(name: String) -> Parameter(List(String), _) {
  use params <- new_parameter(name, LS, fn(s) {
    s
    |> parse.strings
    |> result.map_error(fn(e) { e |> parse.error_to_string |> snag.new })
  })
  use v <- result.try(dict.get(params, name))
  case v {
    LS(param) -> option.to_result(param.internal.value, Nil)
    _ -> Error(Nil)
  }
}

pub fn float(name: String) -> Parameter(Float, _) {
  use params <- new_parameter(name, F, fn(s) {
    s
    |> parse.float
    |> result.map_error(fn(e) { e |> parse.error_to_string |> snag.new })
  })
  use v <- result.try(dict.get(params, name))
  case v {
    F(param) -> option.to_result(param.internal.value, Nil)
    _ -> Error(Nil)
  }
}

pub fn floats(name: String) -> Parameter(List(Float), _) {
  use params <- new_parameter(name, LF, fn(s) {
    s
    |> parse.floats
    |> result.map_error(fn(e) { e |> parse.error_to_string |> snag.new })
  })

  use v <- result.try(dict.get(params, name))
  case v {
    LF(param) -> option.to_result(param.internal.value, Nil)
    _ -> Error(Nil)
  }
}

pub fn bool(name: String) -> Parameter(Bool, _) {
  use params <- new_parameter(name, B, fn(s) {
    s
    |> parse.bool
    |> result.map_error(fn(e) { e |> parse.error_to_string |> snag.new })
  })
  use v <- result.try(dict.get(params, name))
  case v {
    B(param) -> option.to_result(param.internal.value, Nil)
    _ -> Error(Nil)
  }
}

/// Add a [`Flag(a)`](#Flag) to a [`Command(a)`](#Command)
///
/// The provided callback is provided a function to fetch the current flag fvalue from the command input [`Flags`](#Flags).
///
/// This function is most ergonomic as part of a `use` chain when building commands.
///
/// ### Example:
///
/// ```gleam
/// ...
/// use repeat <- glint.flag(
///   glint.int("repeat")
///   |> glint.default(1)
///   |> glint.param_help("Repeat the message n-times")
/// )
/// ...
/// use named, unnamed, flags <- glint.command()
/// let repeat_value = repeat(flags)
/// ```
///
pub fn flag(
  p: Parameter(a, Flag),
  f: fn(fn(Flags) -> Result(a, Nil)) -> Command(b),
) -> Command(b) {
  let cmd = f(fn(flags) { p.getter(flags.internal) })
  Command(
    ..cmd,
    flags: Flags(dict.insert(
      cmd.flags.internal,
      p.internal.name,
      p.constructor(p),
    )),
  )
}

/// Add a list of named arguments to a [`Command(a)`](#Command). The value can be retrieved from the command's [`NamedArgs`](#NamedArgs)
///
/// These named arguments will be matched with the first N arguments passed to the command.
///
///
/// **IMPORTANT**:
///
/// - Matched named arguments will **not** be present in the commmand's unnamed args list
///
/// - All named arguments must match for a command to succeed.
///
/// ### Example:
///
/// ```gleam
/// ...
/// use first_name <- glint.named_arg(glint.string("name"))
/// ...
/// use named, unnamed, flags <- glint.command()
/// let first = first_name(named)
/// ```
pub fn named_arg(
  p: Parameter(a, NamedArg),
  f: fn(fn(NamedArgs) -> a) -> Command(b),
) -> Command(b) {
  let cmd =
    f(fn(named_args) {
      let assert Ok(named_arg) = p.getter(named_args.internal)
      named_arg
    })

  Command(..cmd, named_args: [p.constructor(p), ..cmd.named_args])
}

fn parameter_name(p: Parameters(a)) -> String {
  case p {
    B(value) -> value.internal.name
    F(value) -> value.internal.name
    LF(value) -> value.internal.name
    I(value) -> value.internal.name
    LI(value) -> value.internal.name
    LS(value) -> value.internal.name
    S(value) -> value.internal.name
  }
}

fn parse_parameter(
  p: Parameters(a),
  input: String,
) -> Result(#(Parameters(a), String), Snag) {
  case p {
    B(param) -> {
      use x <- result.map(param.internal.parser(input))
      #(
        Parameter(
          ..param,
          internal: parameter.Parameter(..param.internal, value: Some(x)),
        )
          |> param.constructor,
        param.internal.name,
      )
    }

    F(param) -> {
      use x <- result.map(param.internal.parser(input))
      #(
        Parameter(
          ..param,
          internal: parameter.Parameter(..param.internal, value: Some(x)),
        )
          |> param.constructor,
        param.internal.name,
      )
    }
    I(param) -> {
      use x <- result.map(param.internal.parser(input))
      #(
        Parameter(
          ..param,
          internal: parameter.Parameter(..param.internal, value: Some(x)),
        )
          |> param.constructor,
        param.internal.name,
      )
    }
    LF(param) -> {
      use x <- result.map(param.internal.parser(input))
      #(
        Parameter(
          ..param,
          internal: parameter.Parameter(..param.internal, value: Some(x)),
        )
          |> param.constructor,
        param.internal.name,
      )
    }
    LI(param) -> {
      use x <- result.map(param.internal.parser(input))
      #(
        Parameter(
          ..param,
          internal: parameter.Parameter(..param.internal, value: Some(x)),
        )
          |> param.constructor,
        param.internal.name,
      )
    }
    LS(param) -> {
      use x <- result.map(param.internal.parser(input))
      #(
        Parameter(
          ..param,
          internal: parameter.Parameter(..param.internal, value: Some(x)),
        )
          |> param.constructor,
        param.internal.name,
      )
    }
    S(param) -> {
      use x <- result.map(param.internal.parser(input))
      #(
        Parameter(
          ..param,
          internal: parameter.Parameter(..param.internal, value: Some(x)),
        )
          |> param.constructor,
        param.internal.name,
      )
    }
  }
}

fn parameter_help(p: Parameters(a)) -> String {
  case p {
    B(value) -> value.internal.description
    F(value) -> value.internal.description
    LF(value) -> value.internal.description
    I(value) -> value.internal.description
    LI(value) -> value.internal.description
    LS(value) -> value.internal.description
    S(value) -> value.internal.description
  }
}

/// Glint's typed parameters.
///
/// Flags can be created using any of:
/// - [`glint.int`](#int)
/// - [`glint.ints`](#ints)
/// - [`glint.float`](#float)
/// - [`glint.floats`](#floats)
/// - [`glint.string`](#string)
/// - [`glint.strings_flag`](#strings_flag)
/// - [`glint.bool`](#bool)
///
pub opaque type Parameter(kind, usage) {
  Parameter(
    internal: parameter.Parameter(kind, Snag),
    constructor: fn(Parameter(kind, usage)) -> Parameters(usage),
    getter: fn(dict.Dict(String, Parameters(usage))) -> Result(kind, Nil),
  )
}

pub type Parameters(a) {
  I(value: Parameter(Int, a))
  LI(value: Parameter(List(Int), a))
  S(value: Parameter(String, a))
  LS(value: Parameter(List(String), a))
  B(value: Parameter(Bool, a))
  F(value: Parameter(Float, a))
  LF(value: Parameter(List(Float), a))
}
