import gleam
import gleam/bool
import gleam/map
import gleam/string
import gleam/result
import gleam/int
import gleam/list
import gleam/float
import gleam/function
import snag.{Result, Snag}

/// Flag inputs must start with this prefix
pub const prefix = "--"

/// The separation character for flag names and their values
const delimiter = "="

/// Supported flag types.
pub type Value {
  /// Boolean flags, to be passed in as `--flag=true` or `--flag=false`.
  /// Can be toggled by omitting the desired value like `--flag`.
  /// Toggling will negate the existing value.
  B(Bool)

  /// Int flags, to be passed in as `--flag=1`
  I(Int)

  /// List(Int) flags, to be passed in as `--flag=1,2,3`
  LI(List(Int))

  /// Float flags, to be passed in as `--flag=1.0`
  F(Float)

  /// List(Float) flags, to be passed in as `--flag=1.0,2.0`
  LF(List(Float))

  /// String flags, to be passed in as `--flag=hello`
  S(String)

  /// List(String) flags, to be passed in as `--flag=hello,world`
  LS(List(String))
}

/// Associates a name with a flag value
pub type Flag {
  Flag(name: String, value: Value)
}

/// Creates a Flag(name, I(value))
pub fn int(called name: String, default value: Int) -> Flag {
  Flag(name, I(value))
}

/// Creates a Flag(name, LI(value))
pub fn ints(called name: String, default value: List(Int)) -> Flag {
  Flag(name, LI(value))
}

/// Creates a Flag(name, F(value))
pub fn float(called name: String, default value: Float) -> Flag {
  Flag(name, F(value))
}

/// Creates a Flag(name, LF(value))
pub fn floats(called name: String, default value: List(Float)) -> Flag {
  Flag(name, LF(value))
}

/// Creates a Flag(name, S(value))
pub fn string(called name: String, default value: String) -> Flag {
  Flag(name, S(value))
}

/// Creates a Flag(name, LS(value))
pub fn strings(called name: String, default value: List(String)) -> Flag {
  Flag(name, LS(value))
}

/// Creates a Flag(name, B(value))
pub fn bool(called name: String, default value: Bool) -> Flag {
  Flag(name, B(value))
}

/// Associate flag names to their current values.
pub type Map =
  map.Map(String, Value)

/// Convert a list of flags to a Map.
pub fn build_map(flags: List(Flag)) -> Map {
  list.fold(
    flags,
    map.new(),
    fn(m, flag: Flag) { map.insert(m, flag.name, flag.value) },
  )
}

/// Updates a flag balue, ensuring that the new value can satisfy the required type.
/// Assumes that all flag inputs passed in start with --
/// This function is only intended to be used from glint.execute_root
pub fn update_flags(in flags: Map, with flag_input: String) -> Result(Map) {
  let flag_input = string.drop_left(flag_input, string.length(prefix))
  case string.split_once(flag_input, delimiter) {
    Error(_) -> {
      try default = access_flag(flags, flag_input)
      case default {
        B(val) ->
          B(bool.negate(val))
          |> map.insert(into: flags, for: flag_input)
          |> Ok()
        _ -> Error(no_value_flag_err(flag_input))
      }
    }
    Ok(#(key, value)) -> {
      try default = access_flag(flags, key)
      default
      |> compute_flag(for: key, with: value)
      |> result.map(map.insert(flags, key, _))
    }
  }
}

/// Gets the current Value for the associated flag
fn access_flag(flags: Map, name: String) -> Result(Value) {
  map.get(flags, name)
  |> result.replace_error(undefined_flag_err(name))
}

/// Computes the new flag value given the input and the expected flag type 
fn compute_flag(
  for name: String,
  with value: String,
  given default: Value,
) -> Result(Value) {
  case default {
    I(_) -> parse_int
    LI(_) -> parse_int_list
    F(_) -> parse_float
    LF(_) -> parse_float_list
    S(_) -> parse_string
    LS(_) -> parse_string_list
    B(_) -> parse_bool
  }(
    name,
    value,
  )
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
