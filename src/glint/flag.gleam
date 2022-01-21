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
  Flag(name: String, value: FlagValue)
}

/// Creates a Flag(name, I(value))
pub fn int(called name: String, default value: Int) -> Flag {
  Flag(name, I(value))
}

/// Creates a Flag(name, F(value))
pub fn float(called name: String, default value: Float) -> Flag {
  Flag(name, F(value))
}

/// Creates a Flag(name, LF(value))
pub fn float_list(called name: String, default value: List(Float)) -> Flag {
  Flag(name, LF(value))
}

/// Creates a Flag(name, LI(value))
pub fn int_list(called name: String, default value: List(Int)) -> Flag {
  Flag(name, LI(value))
}

/// Creates a Flag(name, S(value))
pub fn string(called name: String, default value: String) -> Flag {
  Flag(name, S(value))
}

/// Creates a Flag(name, LS(value))
pub fn string_list(called name: String, default value: List(String)) -> Flag {
  Flag(name, LS(value))
}

/// Creates a Flag(name, B(value))
pub fn bool(called name: String, default value: Bool) -> Flag {
  Flag(name, B(value))
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

  case default {
    I(_) -> parse_int
    LI(_) -> parse_int_list
    F(_) -> parse_float
    LF(_) -> parse_float_list
    S(_) -> parse_string
    LS(_) -> parse_string_list
    B(_) -> parse_bool
  }(
    key,
    value,
  )
  |> result.map(map.insert(flags, key, _))
}

// Parser functions
fn parse_int(key, value) {
  value
  |> int.parse()
  |> result.map(I)
  |> result.replace_error(cannot_parse(key, value, "int"))
}

fn parse_int_list(key, value) {
  value
  |> string.split(",")
  |> list.try_map(int.parse)
  |> result.map(LI)
  |> result.replace_error(cannot_parse(key, value, "int list"))
}

fn parse_float(key, value) {
  value
  |> float.parse()
  |> result.map(F)
  |> result.replace_error(cannot_parse(key, value, "float"))
}

fn parse_float_list(key, value) {
  value
  |> string.split(",")
  |> list.try_map(float.parse)
  |> result.map(LF)
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
  value
  |> S
  |> Ok
}

fn parse_string_list(_key, value) {
  value
  |> string.split(",")
  |> LS
  |> Ok
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
