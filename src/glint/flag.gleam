import gleam
import gleam/map
import gleam/string
import gleam/result
import gleam/int
import gleam/list
import gleam/float
import snag.{Result, Snag}

/// Flag inputs must start with this prefix
///
pub const prefix = "--"

/// The separation character for flag names and their values
const delimiter = "="

/// Supported flag types.
///
pub type Value {
  /// Boolean flags, to be passed in as `--flag=true` or `--flag=false`.
  /// Can be toggled by omitting the desired value like `--flag`.
  /// Toggling will negate the existing value.
  ///
  B(Bool)

  /// Int flags, to be passed in as `--flag=1`
  ///
  I(Int)

  /// List(Int) flags, to be passed in as `--flag=1,2,3`
  ///
  LI(List(Int))

  /// Float flags, to be passed in as `--flag=1.0`
  ///
  F(Float)

  /// List(Float) flags, to be passed in as `--flag=1.0,2.0`
  ///
  LF(List(Float))

  /// String flags, to be passed in as `--flag=hello`
  ///
  S(String)

  /// List(String) flags, to be passed in as `--flag=hello,world`
  ///
  LS(List(String))
}

/// Flag descriptions
///
pub type Description =
  String

/// Flag data and descriptions
///
pub opaque type Contents {
  Contents(value: Value, description: Description)
}

/// Associates a name with a flag value
///
pub type Flag =
  #(String, Contents)

/// Creates a #(name, Contents(I(value), description))
///
pub fn int(
  called name: String,
  default value: Int,
  explained description: Description,
) -> Flag {
  #(name, Contents(I(value), description))
}

/// Creates a #(name, Contents(LI(value), description))
///
pub fn ints(
  called name: String,
  default value: List(Int),
  explained description: Description,
) -> Flag {
  #(name, Contents(LI(value), description))
}

/// Creates a #(name, Contents(F(value), description))
///
pub fn float(
  called name: String,
  default value: Float,
  explained description: Description,
) -> Flag {
  #(name, Contents(F(value), description))
}

/// Creates a  #(name, Contents(LF(value), description))
///
pub fn floats(
  called name: String,
  default value: List(Float),
  explained description: Description,
) -> Flag {
  #(name, Contents(LF(value), description))
}

/// Creates a #(name, Contents(S(value), description))
///
pub fn string(
  called name: String,
  default value: String,
  explained description: Description,
) -> Flag {
  #(name, Contents(S(value), description))
}

/// Creates a #(name, Contents(LS(value), description))
///
pub fn strings(
  called name: String,
  default value: List(String),
  explained description: Description,
) -> Flag {
  #(name, Contents(LS(value), description))
}

/// Creates a #(name, Contents(B(value), description))
///
pub fn bool(
  called name: String,
  default value: Bool,
  explained description: Description,
) -> Flag {
  #(name, Contents(B(value), description))
}

/// Associate flag names to their current values.
///
pub type Map =
  map.Map(String, Contents)

/// Convert a list of flags to a Map.
///
pub fn build_map(flags: List(Flag)) -> Map {
  map.from_list(flags)
}

/// Updates a flag value, ensuring that the new value can satisfy the required type.
/// Assumes that all flag inputs passed in start with --
/// This function is only intended to be used from glint.execute_root
///
pub fn update_flags(in flags: Map, with flag_input: String) -> Result(Map) {
  let flag_input = string.drop_left(flag_input, string.length(prefix))

  case string.split_once(flag_input, delimiter) {
    Ok(data) -> update_flag_value(flags, data)
    Error(_) -> attempt_toggle_flag(flags, flag_input)
  }
}

fn update_flag_value(in flags: Map, with data: #(String, String)) -> Result(Map) {
  let #(key, value) = data
  try Contents(default, desc) = access(flags, key)
  default
  |> compute_flag(for: key, with: value)
  |> result.map(Contents(_, desc))
  |> result.map(map.insert(flags, key, _))
}

fn attempt_toggle_flag(in flags: Map, at key: String) -> Result(Map) {
  try Contents(default, desc) = access(flags, key)
  case default {
    B(val) ->
      !val
      |> B
      |> Contents(desc)
      |> map.insert(into: flags, for: key)
      |> Ok()
    _ -> Error(no_value_flag_err(key))
  }
}

/// Gets the current Value for the associated flag
///
pub fn get(from flags: Map, for name: String) -> gleam.Result(Value, Nil) {
  try contents = map.get(flags, name)
  Ok(contents.value)
}

/// Access the contents for the associated flag
///
fn access(flags: Map, name: String) -> Result(Contents) {
  map.get(flags, name)
  |> result.replace_error(undefined_flag_err(name))
}

/// Computes the new flag value given the input and the expected flag type 
///
fn compute_flag(
  for name: String,
  with input: String,
  given default: Value,
) -> Result(Value) {
  let parse = case default {
    I(_) -> parse_int
    LI(_) -> parse_int_list
    F(_) -> parse_float
    LF(_) -> parse_float_list
    S(_) -> parse_string
    LS(_) -> parse_string_list
    B(_) -> parse_bool
  }

  parse(name, input)
}

// Parser functions
fn parse_int(key, value) {
  parse_flag(value, int.parse, I)
  |> result.replace_error(cannot_parse(key, value, "int"))
}

fn parse_int_list(key, value) {
  parse_list_flag(value, int.parse, LI)
  |> result.replace_error(cannot_parse(key, value, "int list"))
}

fn parse_float(key, value) {
  parse_flag(value, float.parse, F)
  |> result.replace_error(cannot_parse(key, value, "float"))
}

fn parse_float_list(key, value) {
  parse_list_flag(value, float.parse, LF)
  |> result.replace_error(cannot_parse(key, value, "float list"))
}

fn parse_bool(key, value) {
  case value {
    "true" -> Ok(B(True))
    "false" -> Ok(B(False))
    _ -> Error(cannot_parse(key, value, "bool"))
  }
}

fn parse_string(_key, value) {
  parse_flag(value, Ok, S)
}

fn parse_string_list(_key, value) {
  parse_list_flag(value, Ok, LS)
}

fn parse_flag(
  value: String,
  parse: fn(String) -> gleam.Result(a, b),
  construct: fn(a) -> Value,
) -> gleam.Result(Value, b) {
  value
  |> parse()
  |> result.map(construct)
}

fn parse_list_flag(
  value: String,
  parse: fn(String) -> gleam.Result(a, b),
  construct: fn(List(a)) -> Value,
) -> gleam.Result(Value, b) {
  value
  |> string.split(",")
  |> list.try_map(parse)
  |> result.map(construct)
}

// Error creation and manipulation functions
fn layer_invalid_flag(err: Snag, flag: String) -> Snag {
  ["invalid flag '", flag, "'"]
  |> string.concat()
  |> snag.layer(err, _)
}

fn no_value_flag_err(flag_input: String) -> Snag {
  ["flag '", flag_input, "' has no assigned value"]
  |> string.concat()
  |> snag.new()
  |> layer_invalid_flag(flag_input)
}

fn undefined_flag_err(key: String) -> Snag {
  "flag provided but not defined"
  |> snag.new()
  |> layer_invalid_flag(key)
}

fn cannot_parse(flag key: String, with value: String, is kind: String) -> Snag {
  ["cannot parse flag '", key, "' value '", value, "' as ", kind]
  |> string.concat()
  |> snag.new()
  |> layer_invalid_flag(key)
}

// Help Message Functions
pub fn flag_type_help(flag: Flag) {
  let #(name, contents) = flag
  let kind = case contents.value {
    I(_) -> "INT"
    B(_) -> "BOOL"
    F(_) -> "FLOAT"
    LF(_) -> "FLOAT_LIST"
    LI(_) -> "INT_LIST"
    LS(_) -> "STRING_LIST"
    S(_) -> "STRING"
  }

  string.concat([prefix, name, delimiter, "<", kind, ">"])
}

/// Generate help message for a single flag
///
pub fn flag_help(flag: Flag) -> String {
  string.concat([flag_type_help(flag), "\t\t", { flag.1 }.description])
}

/// Generate help messages for all flags
///
pub fn flags_help(flags: Map) -> String {
  flags
  |> map.to_list
  |> list.map(flag_help)
  |> list.sort(string.compare)
  |> string.join("\n\t")
}
