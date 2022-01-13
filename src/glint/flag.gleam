import gleam/map.{Map}
import gleam/string
import gleam/result
import gleam/int
import gleam/list
import gleam/float
import snag.{Result, Snag}

/// Supported flag types.
pub type FlagValue {
  /// Boolean flags, to be passed in as `--flag=true` or `--flag=false`
  BoolFlag(Bool)

  /// Int flags, to be passed in as `--flag=1`
  IntFlag(Int)

  /// List(Int) flags, to be passed in as `--flag=1,2,3`
  IntListFlag(List(Int))

  /// Float flags, to be passed in as `--flag=1.0`
  FloatFlag(Float)

  /// List(Float) flags, to be passed in as `--flag=1.0,2.0`
  FloatListFlag(List(Float))

  /// String flags, to be passed in as `--flag=hello`
  StringFlag(String)

  /// List(String) flags, to be passed in as `--flag=hello,world`
  StringListFlag(List(String))
}

/// Associates a name with a flag value
pub type Flag {
  Flag(name: String, value: FlagValue)
}

/// Creates a Flag(name, IntFlag(value))
pub fn int(called name: String, default value: Int) -> Flag {
  Flag(name, IntFlag(value))
}

/// Creates a Flag(name, FloagFlag(value))
pub fn float(called name: String, default value: Float) -> Flag {
  Flag(name, FloatFlag(value))
}

/// Creates a Flag(name, FloagListFlag(value))
pub fn float_list(called name: String, default value: List(Float)) -> Flag {
  Flag(name, FloatListFlag(value))
}

/// Creates a Flag(name, IntListFlag(value))
pub fn int_list(called name: String, default value: List(Int)) -> Flag {
  Flag(name, IntListFlag(value))
}

/// Creates a Flag(name, StringFlag(value))
pub fn string(called name: String, default value: String) -> Flag {
  Flag(name, StringFlag(value))
}

/// Creates a Flag(name, StringListFlag(value))
pub fn string_list(called name: String, default value: List(String)) -> Flag {
  Flag(name, StringListFlag(value))
}

/// Creates a Flag(name, BoolFlag(value))
pub fn bool(called name: String, default value: Bool) -> Flag {
  Flag(name, BoolFlag(value))
}

/// Associate flag names to their current values.
pub type FlagMap =
  Map(String, FlagValue)

/// Convert a list of flags to a FlagMap.
pub fn build_map(flags: List(Flag)) -> FlagMap {
  list.fold(
    flags,
    map.new(),
    fn(m, flag: Flag) { map.insert(m, flag.name, flag.value) },
  )
}

/// Updates a flag balue, ensuring that the new value can satisfy the required type.
pub fn update_flags(flags: FlagMap, flag_input: String) -> Result(FlagMap) {
  try #(key, value) =
    flag_input
    |> string.split_once("=")
    |> result.replace_error(no_value_flag_err(flag_input))

  try default =
    map.get(flags, key)
    |> result.replace_error(undefined_flag_err(key))

  let parser = case default {
    IntFlag(_) -> parse_int
    IntListFlag(_) -> parse_int_list
    FloatFlag(_) -> parse_float
    FloatListFlag(_) -> parse_float_list
    StringFlag(_) -> parse_string
    StringListFlag(_) -> parse_string_list
    BoolFlag(_) -> parse_bool
  }

  parser(key, value)
  |> result.map(map.insert(flags, key, _))
}

// Parser functions
fn parse_int(key, value) {
  value
  |> int.parse()
  |> result.replace_error(cannot_parse(key, value, "int"))
  |> result.map(IntFlag)
}

fn parse_int_list(key: String, value: String) -> Result(FlagValue) {
  value
  |> string.split(",")
  |> list.try_map(int.parse)
  |> result.replace_error(cannot_parse(key, value, "int list"))
  |> result.map(IntListFlag)
}

fn parse_float(key, value) {
  value
  |> float.parse()
  |> result.replace_error(cannot_parse(key, value, "float"))
  |> result.map(FloatFlag)
}

fn parse_float_list(key: String, value: String) -> Result(FlagValue) {
  value
  |> string.split(",")
  |> list.try_map(float.parse)
  |> result.replace_error(cannot_parse(key, value, "float list"))
  |> result.map(FloatListFlag)
}

fn parse_bool(key, value) {
  case value {
    "true" -> Ok(BoolFlag(True))
    "false" -> Ok(BoolFlag(False))
    _ -> Error(cannot_parse(key, value, "bool"))
  }
}

fn parse_string(_key, value) {
  value
  |> StringFlag
  |> Ok
}

fn parse_string_list(_key, value) {
  value
  |> string.split(",")
  |> StringListFlag
  |> Ok
}

// Error creation functions
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
