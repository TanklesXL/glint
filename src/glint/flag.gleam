import gleam/map
import gleam/string
import gleam/result
import gleam/int
import gleam/list
import gleam/float
import snag.{Result, Snag}
import gleam/option.{None, Option, Some}
import glint/flag/constraint.{Constraint}

/// Flag inputs must start with this prefix
///
pub const prefix = "--"

/// The separation character for flag names and their values
const delimiter = "="

/// Supported flag types.
///
pub opaque type Value {
  /// Boolean flags, to be passed in as `--flag=true` or `--flag=false`.
  /// Can be toggled by omitting the desired value like `--flag`.
  /// Toggling will negate the existing value.
  ///
  B(Option(Bool))

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

/// Flag descriptions
///
pub type Description =
  String

/// Flag data and descriptions
///
pub type Contents {
  Contents(value: Value, description: Description)
}

/// Associates a name with a flag value
///
pub type Flag =
  #(String, Contents)

/// Creates an int flag.
///
pub fn int(
  called name: String,
  explained description: Description,
  with opts: List(FlagOpt(Int)),
) -> Flag {
  #(name, Contents(I(new_internal(opts)), description))
}

/// Creates an int list flag.
///
pub fn ints(
  called name: String,
  explained description: Description,
  with opts: List(FlagOpt(List(Int))),
) -> Flag {
  #(name, Contents(LI(new_internal(opts)), description))
}

/// Creates a float flag.
///
pub fn float(
  called name: String,
  explained description: Description,
  with opts: List(FlagOpt(Float)),
) -> Flag {
  #(name, Contents(F(new_internal(opts)), description))
}

/// Creates a float list flag.
///
pub fn floats(
  called name: String,
  explained description: Description,
  with opts: List(FlagOpt(List(Float))),
) -> Flag {
  #(name, Contents(LF(new_internal(opts)), description))
}

/// Creates a string flag.
///
pub fn string(
  called name: String,
  explained description: Description,
  with opts: List(FlagOpt(String)),
) -> Flag {
  #(name, Contents(S(new_internal(opts)), description))
}

/// Creates a string list flag.
///
pub fn strings(
  called name: String,
  explained description: Description,
  with opts: List(FlagOpt(List(String))),
) -> Flag {
  #(name, Contents(LS(new_internal(opts)), description))
}

/// Creates a bool flag.
///
pub fn bool(
  called name: String,
  default value: Option(Bool),
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
  use contents <- result.then(access(flags, key))
  contents.value
  |> compute_flag(for: key, with: value)
  |> result.map(Contents(_, contents.description))
  |> result.map(map.insert(flags, key, _))
}

fn attempt_toggle_flag(in flags: Map, at key: String) -> Result(Map) {
  use contents <- result.then(access(flags, key))
  case contents.value {
    B(None) ->
      Some(True)
      |> B
      |> Contents(contents.description)
      |> map.insert(into: flags, for: key)
      |> Ok()
    B(Some(val)) ->
      Some(!val)
      |> B
      |> Contents(contents.description)
      |> map.insert(into: flags, for: key)
      |> Ok()
    _ -> Error(no_value_flag_err(key))
  }
}

fn access_type_error(name, flag_type) {
  snag.error("cannot access flag " <> name <> " as " <> flag_type)
}

fn flag_not_provided_error(name) {
  snag.error("value for flag " <> name <> " not provided")
}

fn apply_constraints(
  name: String,
  val: a,
  constraints: List(Constraint(a)),
) -> Result(a) {
  list.try_map(constraints, fn(c) { c(val) })
  |> snag.context("value for flag " <> name <> " does not satisfy constraints")
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
    I(Internal(constraints: constraints, ..) as internal) ->
      parse_int(name, input)
      |> result.then(apply_constraints(name, _, constraints))
      |> result.map(fn(i) { I(Internal(..internal, value: Some(i))) })
    LI(Internal(constraints: constraints, ..) as internal) ->
      parse_int_list(name, input)
      |> result.then(apply_constraints(name, _, constraints))
      |> result.map(fn(li) { LI(Internal(..internal, value: Some(li))) })
    F(Internal(constraints: constraints, ..) as internal) ->
      parse_float(name, input)
      |> result.then(apply_constraints(name, _, constraints))
      |> result.map(fn(f) { F(Internal(..internal, value: Some(f))) })
    LF(Internal(constraints: constraints, ..) as internal) ->
      parse_float_list(name, input)
      |> result.then(apply_constraints(name, _, constraints))
      |> result.map(fn(lf) { LF(Internal(..internal, value: Some(lf))) })
    S(Internal(constraints: constraints, ..) as internal) ->
      parse_string(name, input)
      |> result.then(apply_constraints(name, _, constraints))
      |> result.map(fn(s) { S(Internal(..internal, value: Some(s))) })
    LS(Internal(constraints: constraints, ..) as internal) ->
      parse_string_list(name, input)
      |> result.then(apply_constraints(name, _, constraints))
      |> result.map(fn(ls) { LS(Internal(..internal, value: Some(ls))) })
    B(_) ->
      parse_bool(name, input)
      |> result.map(fn(b) { B(Some(b)) })
  }
}

// Parser functions
fn parse_int(key, value) {
  int.parse(value)
  |> result.replace_error(cannot_parse(key, value, "int"))
}

fn parse_int_list(key, value) {
  value
  |> string.split(",")
  |> list.try_map(int.parse)
  |> result.replace_error(cannot_parse(key, value, "int list"))
}

fn parse_float(key, value) {
  float.parse(value)
  |> result.replace_error(cannot_parse(key, value, "float"))
}

fn parse_float_list(key, value) {
  value
  |> string.split(",")
  |> list.try_map(float.parse)
  |> result.replace_error(cannot_parse(key, value, "float list"))
}

fn parse_bool(key, value) -> Result(Bool) {
  case value {
    "true" -> Ok(True)
    "false" -> Ok(False)
    _ -> Error(cannot_parse(key, value, "bool"))
  }
}

fn parse_string(_key, value) {
  Ok(value)
}

fn parse_string_list(_key, value) {
  value
  |> string.split(",")
  |> Ok
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

  prefix <> name <> delimiter <> "<" <> kind <> ">"
}

/// Generate help message line for a single flag
///
fn flag_help(flag: Flag) -> String {
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
fn access(flags: Map, name: String) -> Result(Contents) {
  map.get(flags, name)
  |> result.replace_error(undefined_flag_err(name))
}

/// Gets the current value for the provided int flag
///
pub fn get_int_value(from flag: Flag) -> Result(Int) {
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
pub fn get_ints_value(from flag: Flag) -> Result(List(Int)) {
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
pub fn get_bool_value(from flag: Flag) -> Result(Bool) {
  case { flag.1 }.value {
    B(Some(val)) -> Ok(val)
    B(None) -> flag_not_provided_error(flag.0)
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
pub fn get_string_value(from flag: Flag) -> Result(String) {
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
pub fn get_strings_value(from flag: Flag) -> Result(List(String)) {
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
pub fn get_float_value(from flag: Flag) -> Result(Float) {
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
pub fn get_floats_value(from flag: Flag) -> Result(List(Float)) {
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

pub type FlagOpt(a) {
  WithDefault(a)
  WithConstraint(Constraint(a))
}

type Internal(a) {
  Internal(value: Option(a), constraints: List(Constraint(a)))
}

fn apply_opts(to flag: Internal(a), opts opts: List(FlagOpt(a))) -> Internal(a) {
  use flag, opt <- list.fold(opts, flag)
  case opt {
    WithDefault(default) -> Internal(..flag, value: Some(default))
    WithConstraint(constraint) ->
      Internal(..flag, constraints: [constraint, ..flag.constraints])
  }
}

fn new_internal(with opts: List(FlagOpt(a))) -> Internal(a) {
  Internal(value: None, constraints: [])
  |> apply_opts(opts)
}
