import gleam/map
import gleam/string
import gleam/result
import gleam/int
import gleam/list
import gleam/float
import snag.{Result, Snag}
import gleam/option.{None, Option, Some}
import gleam/function.{apply1}
import glint/flag/constraint.{Constraint}

/// Flag inputs must start with this prefix
///
pub const prefix = "--"

/// The separation character for flag names and their values
const delimiter = "="

/// Supported flag types.
/// The constructors of this Value type can also be used as `ValueBuilder`s
///
pub type Value {
  /// Boolean flags, to be passed in as `--flag=true` or `--flag=false`.
  /// Can be toggled by omitting the desired value like `--flag`.
  /// Toggling will negate the existing value.
  ///
  B(Internal(Bool))

  /// Int flags, to be passed in as `--flag=1`
  ///
  I(Internal(Int))

  /// List(Int) flags, to be passed in as `--flag=1,2,3`
  ///
  LI(Internal(List(Int)))

  /// Float flags, to be passed in as `--flag=1.0`
  ///
  F(Internal(Float))

  /// List(Float) flags, to be passed in as `--flag=1.0,2.0`
  ///
  LF(Internal(List(Float)))

  /// String flags, to be passed in as `--flag=hello`
  ///
  S(Internal(String))

  /// List(String) flags, to be passed in as `--flag=hello,world`
  ///
  LS(Internal(List(String)))
}

/// A type that facilitates the usage of builder functions for creating `Value`s
///
pub type ValueBuilder(a) =
  fn(Internal(a)) -> Value

/// An internal representation of flag contents
///
pub opaque type Internal(a) {
  Internal(value: Option(a), constraints: List(Constraint(a)))
}

/// Flag descriptions
///
pub type Description =
  String

/// Flag data and descriptions
///
pub type Flag {
  Flag(value: Value, description: Description)
}

/// create a new `Flag`
///
pub fn new(of val: ValueBuilder(a)) -> Flag {
  let value = val(Internal(None, []))
  Flag(value: value, description: "")
}

/// attach a description to a `Flag`
///
pub fn description(for flag: Flag, of description: Description) -> Flag {
  Flag(..flag, description: description)
}

/// attach a constraint to a `Value`
///
pub fn constraint(
  for val: ValueBuilder(a),
  of constraint: Constraint(a),
) -> ValueBuilder(a) {
  fn(internal) {
    val(Internal(..internal, constraints: [constraint, ..internal.constraints]))
  }
}

/// Set the default value for a flag `Value`
///
pub fn default(for val: ValueBuilder(a), of default: a) -> ValueBuilder(a) {
  fn(internal) { val(Internal(..internal, value: Some(default))) }
}

/// Associate flag names to their current values.
///
pub type Map =
  map.Map(String, Flag)

/// Convert a list of flags to a Map.
///
pub fn build_map(flags: List(#(String, Flag))) -> Map {
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
  let #(key, input) = data
  use contents <- result.then(access(flags, key))
  use value <- result.map(compute_flag(
    for: key,
    with: input,
    given: contents.value,
  ))
  map.insert(flags, key, Flag(..contents, value: value))
}

fn attempt_toggle_flag(in flags: Map, at key: String) -> Result(Map) {
  use contents <- result.then(access(flags, key))
  case contents.value {
    B(Internal(None, ..) as internal) ->
      Internal(..internal, value: Some(True))
      |> B
      |> fn(val) { Flag(..contents, value: val) }
      |> map.insert(into: flags, for: key)
      |> Ok()
    B(Internal(Some(val), ..) as internal) ->
      Internal(..internal, value: Some(!val))
      |> B
      |> fn(val) { Flag(..contents, value: val) }
      |> map.insert(into: flags, for: key)
      |> Ok()
    _ -> Error(no_value_flag_err(key))
  }
}

fn access_type_error(name, flag_type) {
  snag.error("cannot access flag '" <> name <> "' as " <> flag_type)
}

fn flag_not_provided_error(name) {
  snag.error("value for flag '" <> name <> "' not provided")
}

fn apply_constraints(
  name: String,
  val: a,
  constraints: List(Constraint(a)),
) -> Result(a) {
  constraints
  |> list.try_map(apply1(_, val))
  |> snag.context(
    "value for flag '" <> name <> "' does not satisfy constraints",
  )
  |> result.replace(val)
}

/// Computes the new flag value given the input and the expected flag type 
///
fn compute_flag(
  for name: String,
  with input: String,
  given default: Value,
) -> Result(Value) {
  case default {
    I(internal) -> parse_int(name, input, internal)
    LI(internal) -> parse_int_list(name, input, internal)
    F(internal) -> parse_float(name, input, internal)
    LF(internal) -> parse_float_list(name, input, internal)
    S(internal) -> parse_string(name, input, internal)
    LS(internal) -> parse_string_list(name, input, internal)
    B(internal) -> parse_bool(name, input, internal)
  }
}

// Parser functions
fn parse_int(key, value, internal: Internal(Int)) {
  use i <- result.then(
    int.parse(value)
    |> result.replace_error(cannot_parse(key, value, "int")),
  )

  apply_constraints(key, i, internal.constraints)
  |> result.replace(I(Internal(..internal, value: Some(i))))
}

fn parse_int_list(key, value, internal: Internal(List(Int))) {
  use li <- result.then(
    value
    |> string.split(",")
    |> list.try_map(int.parse)
    |> result.replace_error(cannot_parse(key, value, "int list")),
  )

  apply_constraints(key, li, internal.constraints)
  |> result.replace(LI(Internal(..internal, value: Some(li))))
}

// fn xxx(key,val,constraints){apply_constraints(key, li, internal.constraints)|> }
fn parse_float(key, value, internal: Internal(Float)) {
  use f <- result.then(
    float.parse(value)
    |> result.replace_error(cannot_parse(key, value, "float")),
  )

  apply_constraints(key, f, internal.constraints)
  |> result.replace(F(Internal(..internal, value: Some(f))))
}

fn parse_float_list(key, value, internal: Internal(List(Float))) {
  use lf <- result.then(
    value
    |> string.split(",")
    |> list.try_map(float.parse)
    |> result.replace_error(cannot_parse(key, value, "float list")),
  )
  apply_constraints(key, lf, internal.constraints)
  |> result.replace(LF(Internal(..internal, value: Some(lf))))
}

fn parse_bool(key, value, internal: Internal(Bool)) {
  use val <- result.then(case string.lowercase(value) {
    "true" | "t" -> Ok(True)
    "false" | "f" -> Ok(False)
    _ -> Error(cannot_parse(key, value, "bool"))
  })

  apply_constraints(key, val, internal.constraints)
  |> result.replace(B(Internal(..internal, value: Some(val))))
}

fn parse_string(key, value, internal: Internal(String)) {
  apply_constraints(key, value, internal.constraints)
  |> result.replace(S(Internal(..internal, value: Some(value))))
}

fn parse_string_list(key, value, internal: Internal(List(String))) {
  let value = string.split(value, ",")

  value
  |> apply_constraints(key, _, internal.constraints)
  |> result.replace(LS(Internal(..internal, value: Some(value))))
}

// Error creation and manipulation functions
fn layer_invalid_flag(err: Snag, flag: String) -> Snag {
  "invalid flag '" <> flag <> "'"
  |> snag.layer(err, _)
}

fn no_value_flag_err(flag_input: String) -> Snag {
  "flag '" <> flag_input <> "' has no assigned value"
  |> snag.new()
  |> layer_invalid_flag(flag_input)
}

fn undefined_flag_err(key: String) -> Snag {
  "flag provided but not defined"
  |> snag.new()
  |> layer_invalid_flag(key)
}

fn cannot_parse(flag key: String, with value: String, is kind: String) -> Snag {
  "cannot parse flag '" <> key <> "' value '" <> value <> "' as " <> kind
  |> snag.new()
  |> layer_invalid_flag(key)
}

// Help Message Functions
/// Generate the help message contents for a single flag
/// 
pub fn flag_type_help(flag: #(String, Flag)) {
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

  prefix <> name <> delimiter <> "<" <> kind <> ">"
}

/// Generate help message line for a single flag
///
fn flag_help(flag: #(String, Flag)) -> String {
  flag_type_help(flag) <> "\t\t" <> { flag.1 }.description
}

/// Generate help messages for all flags
///
pub fn flags_help(flags: Map) -> List(String) {
  flags
  |> map.to_list
  |> list.map(flag_help)
}

/// Access the contents for the associated flag
///
fn access(flags: Map, name: String) -> Result(Flag) {
  map.get(flags, name)
  |> result.replace_error(undefined_flag_err(name))
}

/// Gets the current value for the provided int flag
///
pub fn get_int_value(from flag: #(String, Flag)) -> Result(Int) {
  case { flag.1 }.value {
    I(Internal(value: Some(val), ..)) -> Ok(val)
    I(Internal(value: None, ..)) -> flag_not_provided_error(flag.0)
    _ -> access_type_error(flag.0, "int")
  }
}

/// Gets the current value for the associated int flag
///
pub fn get_int(from flags: Map, for name: String) -> Result(Int) {
  use value <- result.then(access(flags, name))
  get_int_value(#(name, value))
}

/// Gets the current value for the provided ints flag
///
pub fn get_ints_value(from flag: #(String, Flag)) -> Result(List(Int)) {
  case { flag.1 }.value {
    LI(Internal(value: Some(val), ..)) -> Ok(val)
    LI(Internal(value: None, ..)) -> flag_not_provided_error(flag.0)
    _ -> access_type_error(flag.0, "int list")
  }
}

/// Gets the current value for the associated ints flag
///
pub fn get_ints(from flags: Map, for name: String) -> Result(List(Int)) {
  use value <- result.then(access(flags, name))
  get_ints_value(#(name, value))
}

/// Gets the current value for the provided bool flag
///
pub fn get_bool_value(from flag: #(String, Flag)) -> Result(Bool) {
  case { flag.1 }.value {
    B(Internal(Some(val), ..)) -> Ok(val)
    B(Internal(None, ..)) -> flag_not_provided_error(flag.0)
    _ -> access_type_error(flag.0, "bool")
  }
}

/// Gets the current value for the associated bool flag
///
pub fn get_bool(from flags: Map, for name: String) -> Result(Bool) {
  use value <- result.then(access(flags, name))
  get_bool_value(#(name, value))
}

/// Gets the current value for the provided string flag
///
pub fn get_string_value(from flag: #(String, Flag)) -> Result(String) {
  case { flag.1 }.value {
    S(Internal(value: Some(val), ..)) -> Ok(val)
    S(Internal(value: None, ..)) -> flag_not_provided_error(flag.0)
    _ -> access_type_error(flag.0, "string")
  }
}

/// Gets the current value for the associated string flag
///
pub fn get_string(from flags: Map, for name: String) -> Result(String) {
  use value <- result.then(access(flags, name))
  get_string_value(#(name, value))
}

/// Gets the current value for the provided strings flag
///
pub fn get_strings_value(from flag: #(String, Flag)) -> Result(List(String)) {
  case { flag.1 }.value {
    LS(Internal(value: Some(val), ..)) -> Ok(val)
    LS(Internal(value: None, ..)) -> flag_not_provided_error(flag.0)
    _ -> access_type_error(flag.0, "string list")
  }
}

/// Gets the current value for the associated strings flag
///
pub fn get_strings(from flags: Map, for name: String) -> Result(List(String)) {
  use value <- result.then(access(flags, name))
  get_strings_value(#(name, value))
}

/// Gets the current value for the provided float flag
///
pub fn get_float_value(from flag: #(String, Flag)) -> Result(Float) {
  case { flag.1 }.value {
    F(Internal(value: Some(val), ..)) -> Ok(val)
    F(Internal(value: None, ..)) -> flag_not_provided_error(flag.0)
    _ -> access_type_error(flag.0, "float")
  }
}

/// Gets the current value for the associated float flag
///
pub fn get_float(from flags: Map, for name: String) -> Result(Float) {
  use value <- result.then(access(flags, name))
  get_float_value(#(name, value))
}

/// Gets the current value for the provided floats flag
///
pub fn get_floats_value(from flag: #(String, Flag)) -> Result(List(Float)) {
  case { flag.1 }.value {
    LF(Internal(value: Some(val), ..)) -> Ok(val)
    LF(Internal(value: None, ..)) -> flag_not_provided_error(flag.0)
    _ -> access_type_error(flag.0, "float list")
  }
}

/// Gets the current value for the associated floats flag
///
pub fn get_floats(from flags: Map, for name: String) -> Result(List(Float)) {
  use value <- result.then(access(flags, name))
  get_floats_value(#(name, value))
}
