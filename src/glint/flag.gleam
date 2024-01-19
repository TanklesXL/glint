import gleam/dict
import gleam/string
import gleam/result
import gleam/int
import gleam/list
import gleam/float
import snag.{type Result, type Snag}
import gleam/option.{type Option, None, Some}
import glint/flag/constraint.{type Constraint}
import gleam

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

/// A type that facilitates the creation of `Flag`s
///
pub opaque type FlagBuilder(a) {
  FlagBuilder(
    desc: Description,
    parser: Parser(a, Snag),
    value: fn(Internal(a)) -> Value,
    default: Option(a),
  )
}

/// An internal representation of flag contents
///
pub opaque type Internal(a) {
  Internal(value: Option(a), parser: Parser(a, Snag))
}

// Builder initializers

type Parser(a, b) =
  fn(String) -> gleam.Result(a, b)

/// initialise an int flag builder
///
pub fn int() -> FlagBuilder(Int) {
  use input <- new(I)
  input
  |> int.parse
  |> result.replace_error(cannot_parse(input, "int"))
}

/// initialise an int list flag builder
///
pub fn int_list() -> FlagBuilder(List(Int)) {
  use input <- new(LI)
  input
  |> string.split(",")
  |> list.try_map(int.parse)
  |> result.replace_error(cannot_parse(input, "int list"))
}

/// initialise a float flag builder
///
pub fn float() -> FlagBuilder(Float) {
  use input <- new(F)
  input
  |> float.parse
  |> result.replace_error(cannot_parse(input, "float"))
}

/// initialise a float list flag builder
///
pub fn float_list() -> FlagBuilder(List(Float)) {
  use input <- new(LF)
  input
  |> string.split(",")
  |> list.try_map(float.parse)
  |> result.replace_error(cannot_parse(input, "float list"))
}

/// initialise a string flag builder
///
pub fn string() -> FlagBuilder(String) {
  new(S, fn(s) { Ok(s) })
}

/// intitialise a string list flag builder
/// 
pub fn string_list() -> FlagBuilder(List(String)) {
  use input <- new(LS)
  input
  |> string.split(",")
  |> Ok
}

/// initialise a bool flag builder
/// 
pub fn bool() -> FlagBuilder(Bool) {
  use input <- new(B)
  case string.lowercase(input) {
    "true" | "t" -> Ok(True)
    "false" | "f" -> Ok(False)
    _ -> Error(cannot_parse(input, "bool"))
  }
}

/// initialize custom builders using a Value constructor and a parsing function
/// 
fn new(valuer: fn(Internal(a)) -> Value, p: Parser(a, Snag)) -> FlagBuilder(a) {
  FlagBuilder(desc: "", parser: p, value: valuer, default: None)
}

/// convert a FlagBuilder(a) into its corresponding Flag representation
/// 
pub fn build(fb: FlagBuilder(a)) -> Flag {
  Flag(
    value: fb.value(Internal(value: fb.default, parser: fb.parser)),
    description: fb.desc,
  )
}

/// attach a constraint to a `Flag`
///
pub fn constraint(
  builder: FlagBuilder(a),
  constraint: Constraint(a),
) -> FlagBuilder(a) {
  FlagBuilder(
    ..builder,
    parser: wrap_with_constraint(builder.parser, constraint),
  )
}

/// attach a Constraint(a) to a Parser(a,Snag)
/// this function should not be used directly unless 
fn wrap_with_constraint(
  p: Parser(a, Snag),
  constraint: Constraint(a),
) -> Parser(a, Snag) {
  fn(input: String) -> Result(a) { attempt(p(input), constraint) }
}

fn attempt(
  val: gleam.Result(a, e),
  f: fn(a) -> gleam.Result(_, e),
) -> gleam.Result(a, e) {
  use a <- result.try(val)
  result.replace(f(a), a)
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

/// attach a description to a `Flag`
///
pub fn description(
  for builder: FlagBuilder(a),
  of description: Description,
) -> FlagBuilder(a) {
  FlagBuilder(..builder, desc: description)
}

/// Set the default value for a flag `Value`
///
pub fn default(for builder: FlagBuilder(a), of default: a) -> FlagBuilder(a) {
  FlagBuilder(..builder, default: Some(default))
}

/// Associate flag names to their current values.
///
pub type Map =
  dict.Dict(String, Flag)

/// Convert a list of flags to a Map.
///
pub fn build_map(flags: List(#(String, Flag))) -> Map {
  dict.from_list(flags)
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
  use contents <- result.try(access(flags, key))
  use value <- result.map(
    compute_flag(with: input, given: contents.value)
    |> result.map_error(layer_invalid_flag(_, key)),
  )
  dict.insert(flags, key, Flag(..contents, value: value))
}

fn attempt_toggle_flag(in flags: Map, at key: String) -> Result(Map) {
  use contents <- result.try(access(flags, key))
  case contents.value {
    B(Internal(None, ..) as internal) ->
      Internal(..internal, value: Some(True))
      |> B
      |> fn(val) { Flag(..contents, value: val) }
      |> dict.insert(into: flags, for: key)
      |> Ok
    B(Internal(Some(val), ..) as internal) ->
      Internal(..internal, value: Some(!val))
      |> B
      |> fn(val) { Flag(..contents, value: val) }
      |> dict.insert(into: flags, for: key)
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
  internal: Internal(a),
  constructor: fn(Internal(a)) -> Value,
) -> Result(Value) {
  use val <- result.map(internal.parser(input))
  constructor(Internal(..internal, value: Some(val)))
}

/// Computes the new flag value given the input and the expected flag type 
///
fn compute_flag(with input: String, given current: Value) -> Result(Value) {
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
fn access(flags: Map, name: String) -> Result(Flag) {
  dict.get(flags, name)
  |> result.replace_error(undefined_flag_err(name))
}

fn get_value(
  from flags: Map,
  at key: String,
  expecting kind: fn(Flag) -> Result(a),
) -> Result(a) {
  access(flags, key)
  |> result.try(kind)
  |> snag.context("failed to retrieve value for flag '" <> key <> "'")
}

/// Gets the current value for the provided int flag
///
pub fn get_int_value(from flag: Flag) -> Result(Int) {
  case flag.value {
    I(Internal(value: Some(val), ..)) -> Ok(val)
    I(Internal(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("int")
  }
}

/// Gets the current value for the associated int flag
///
pub fn get_int(from flags: Map, for name: String) -> Result(Int) {
  get_value(flags, name, get_int_value)
}

/// Gets the current value for the provided ints flag
///
pub fn get_ints_value(from flag: Flag) -> Result(List(Int)) {
  case flag.value {
    LI(Internal(value: Some(val), ..)) -> Ok(val)
    LI(Internal(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("int list")
  }
}

/// Gets the current value for the associated ints flag
///
pub fn get_ints(from flags: Map, for name: String) -> Result(List(Int)) {
  get_value(flags, name, get_ints_value)
}

/// Gets the current value for the provided bool flag
///
pub fn get_bool_value(from flag: Flag) -> Result(Bool) {
  case flag.value {
    B(Internal(Some(val), ..)) -> Ok(val)
    B(Internal(None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("bool")
  }
}

/// Gets the current value for the associated bool flag
///
pub fn get_bool(from flags: Map, for name: String) -> Result(Bool) {
  get_value(flags, name, get_bool_value)
}

/// Gets the current value for the provided string flag
///
pub fn get_string_value(from flag: Flag) -> Result(String) {
  case flag.value {
    S(Internal(value: Some(val), ..)) -> Ok(val)
    S(Internal(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("string")
  }
}

/// Gets the current value for the associated string flag
///
pub fn get_string(from flags: Map, for name: String) -> Result(String) {
  get_value(flags, name, get_string_value)
}

/// Gets the current value for the provided strings flag
///
pub fn get_strings_value(from flag: Flag) -> Result(List(String)) {
  case flag.value {
    LS(Internal(value: Some(val), ..)) -> Ok(val)
    LS(Internal(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("string list")
  }
}

/// Gets the current value for the associated strings flag
///
pub fn get_strings(from flags: Map, for name: String) -> Result(List(String)) {
  get_value(flags, name, get_strings_value)
}

/// Gets the current value for the provided float flag
///
pub fn get_float_value(from flag: Flag) -> Result(Float) {
  case flag.value {
    F(Internal(value: Some(val), ..)) -> Ok(val)
    F(Internal(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("float")
  }
}

/// Gets the current value for the associated float flag
///
pub fn get_float(from flags: Map, for name: String) -> Result(Float) {
  get_value(flags, name, get_float_value)
}

/// Gets the current value for the provided floats flag
///
pub fn get_floats_value(from flag: Flag) -> Result(List(Float)) {
  case flag.value {
    LF(Internal(value: Some(val), ..)) -> Ok(val)
    LF(Internal(value: None, ..)) -> flag_not_provided_error()
    _ -> access_type_error("float list")
  }
}

/// Gets the current value for the associated floats flag
///
pub fn get_floats(from flags: Map, for name: String) -> Result(List(Float)) {
  get_value(flags, name, get_floats_value)
}
