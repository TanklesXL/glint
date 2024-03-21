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
pub opaque type Builder(a) {
  Builder(
    desc: Description,
    parser: Parser(a, Snag),
    value: fn(Internal(a)) -> Value,
    getter: fn(Flags, String) -> Result(a),
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
pub fn int() -> Builder(Int) {
  use input <- new(I, get_int)
  input
  |> int.parse
  |> result.replace_error(cannot_parse(input, "int"))
}

/// initialise an int list flag builder
///
pub fn int_list() -> Builder(List(Int)) {
  use input <- new(LI, get_ints)
  input
  |> string.split(",")
  |> list.try_map(int.parse)
  |> result.replace_error(cannot_parse(input, "int list"))
}

/// initialise a float flag builder
///
pub fn float() -> Builder(Float) {
  use input <- new(F, get_float)
  input
  |> float.parse
  |> result.replace_error(cannot_parse(input, "float"))
}

/// initialise a float list flag builder
///
pub fn float_list() -> Builder(List(Float)) {
  use input <- new(LF, get_floats)
  input
  |> string.split(",")
  |> list.try_map(float.parse)
  |> result.replace_error(cannot_parse(input, "float list"))
}

/// initialise a string flag builder
///
pub fn string() -> Builder(String) {
  new(S, get_string, fn(s) { Ok(s) })
}

/// intitialise a string list flag builder
///
pub fn string_list() -> Builder(List(String)) {
  use input <- new(LS, get_strings)
  input
  |> string.split(",")
  |> Ok
}

/// initialise a bool flag builder
///
pub fn bool() -> Builder(Bool) {
  use input <- new(B, get_bool)
  case string.lowercase(input) {
    "true" | "t" -> Ok(True)
    "false" | "f" -> Ok(False)
    _ -> Error(cannot_parse(input, "bool"))
  }
}

/// initialize custom builders using a Value constructor and a parsing function
///
fn new(
  valuer: fn(Internal(a)) -> Value,
  getter: fn(Flags, String) -> Result(a),
  p: Parser(a, Snag),
) -> Builder(a) {
  Builder(desc: "", parser: p, value: valuer, default: None, getter: getter)
}

/// convert a Builder(a) into its corresponding Flag representation
///
pub fn build(fb: Builder(a)) -> Flag {
  Flag(
    value: fb.value(Internal(value: fb.default, parser: fb.parser)),
    description: fb.desc,
  )
}

/// convert a Builder(a) into its corresponding Flag representation as well as retrieve it's accessor function
///
pub fn build_access(fb: Builder(a)) -> #(Flag, fn(Flags, String) -> Result(a)) {
  #(
    Flag(
      value: fb.value(Internal(value: fb.default, parser: fb.parser)),
      description: fb.desc,
    ),
    fb.getter,
  )
}

/// attach a constraint to a `Flag`
///
pub fn constraint(builder: Builder(a), constraint: Constraint(a)) -> Builder(a) {
  Builder(..builder, parser: wrap_with_constraint(builder.parser, constraint))
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
  for builder: Builder(a),
  of description: Description,
) -> Builder(a) {
  Builder(..builder, desc: description)
}

/// Set the default value for a flag `Value`
///
pub fn default(for builder: Builder(a), of default: a) -> Builder(a) {
  Builder(..builder, default: Some(default))
}

/// Flag names and their associated values
///
pub opaque type Flags {
  Flags(internal: dict.Dict(String, Flag))
}

pub fn insert(flags: Flags, name: String, flag: Flag) -> Flags {
  Flags(dict.insert(flags.internal, name, flag))
}

pub fn merge(into a: Flags, from b: Flags) -> Flags {
  Flags(internal: dict.merge(a.internal, b.internal))
}

pub fn fold(flags: Flags, acc: acc, f: fn(acc, String, Flag) -> acc) -> acc {
  dict.fold(flags.internal, acc, f)
}

/// Convert a list of flags to a Flags.
///
pub fn build_flags(flags: List(#(String, Flag))) -> Flags {
  Flags(dict.from_list(flags))
}

/// Updates a flag value, ensuring that the new value can satisfy the required type.
/// Assumes that all flag inputs passed in start with --
/// This function is only intended to be used from glint.execute_root
///
pub fn update_flags(in flags: Flags, with flag_input: String) -> Result(Flags) {
  let flag_input = string.drop_left(flag_input, string.length(prefix))

  case string.split_once(flag_input, delimiter) {
    Ok(data) -> update_flag_value(flags, data)
    Error(_) -> attempt_toggle_flag(flags, flag_input)
  }
}

fn update_flag_value(
  in flags: Flags,
  with data: #(String, String),
) -> Result(Flags) {
  let #(key, input) = data
  use contents <- result.try(get(flags, key))
  use value <- result.map(
    compute_flag(with: input, given: contents.value)
    |> result.map_error(layer_invalid_flag(_, key)),
  )
  insert(flags, key, Flag(..contents, value: value))
}

fn attempt_toggle_flag(in flags: Flags, at key: String) -> Result(Flags) {
  use contents <- result.try(get(flags, key))
  case contents.value {
    B(Internal(None, ..) as internal) ->
      Internal(..internal, value: Some(True))
      |> B
      |> fn(val) { Flag(..contents, value: val) }
      |> dict.insert(into: flags.internal, for: key)
      |> Flags
      |> Ok
    B(Internal(Some(val), ..) as internal) ->
      Internal(..internal, value: Some(!val))
      |> B
      |> fn(val) { Flag(..contents, value: val) }
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
pub fn get(flags: Flags, name: String) -> Result(Flag) {
  dict.get(flags.internal, name)
  |> result.replace_error(undefined_flag_err(name))
}

fn get_value(
  from flags: Flags,
  at key: String,
  expecting kind: fn(Flag) -> Result(a),
) -> Result(a) {
  get(flags, key)
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
pub fn get_int(from flags: Flags, for name: String) -> Result(Int) {
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
pub fn get_ints(from flags: Flags, for name: String) -> Result(List(Int)) {
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
pub fn get_bool(from flags: Flags, for name: String) -> Result(Bool) {
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
pub fn get_string(from flags: Flags, for name: String) -> Result(String) {
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
pub fn get_strings(from flags: Flags, for name: String) -> Result(List(String)) {
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
pub fn get_float(from flags: Flags, for name: String) -> Result(Float) {
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
pub fn get_floats(from flags: Flags, for name: String) -> Result(List(Float)) {
  get_value(flags, name, get_floats_value)
}
