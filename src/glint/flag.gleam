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
pub opaque type Value {
  /// Boolean flags, to be passed in as `--flag=true` or `--flag=false`.
  /// Can be toggled by omitting the desired value like `--flag`.
  /// Toggling will negate the existing value.
  ///
  B(Bool)

  /// Int flags, to be passed in as `--flag=1`
  ///
  I(Int, List(Constraint(Int)))

  /// List(Int) flags, to be passed in as `--flag=1,2,3`
  ///
  LI(List(Int), List(Constraint(Int)))

  /// Float flags, to be passed in as `--flag=1.0`
  ///
  F(Float, List(Constraint(Float)))

  /// List(Float) flags, to be passed in as `--flag=1.0,2.0`
  ///
  LF(List(Float), List(Constraint(Float)))

  /// String flags, to be passed in as `--flag=hello`
  ///
  S(String, List(Constraint(String)))

  /// List(String) flags, to be passed in as `--flag=hello,world`
  ///
  LS(List(String), List(Constraint(String)))
}

type Constraint(a) =
  fn(a) -> Result(Nil)

pub fn one_of(val: a, allowed: List(a)) -> Result(a) {
  case list.contains(allowed, val) {
    True -> Ok(val)
    False ->
      snag.error(
        "invalid flag value, must be one of: " <> string.join(
          list.map(allowed, string.inspect),
          ", ",
        ),
      )
  }
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
  satisfying constraints: List(Constraint(Int)),
) -> Flag {
  #(name, Contents(I(value, constraints), description))
}

/// Creates a #(name, Contents(LI(value), description))
///
pub fn ints(
  called name: String,
  default value: List(Int),
  explained description: Description,
  satisfying constraints: List(Constraint(Int)),
) -> Flag {
  #(name, Contents(LI(value, constraints), description))
}

/// Creates a #(name, Contents(F(value), description))
///
pub fn float(
  called name: String,
  default value: Float,
  explained description: Description,
  satisfying constraints: List(Constraint(Float)),
) -> Flag {
  #(name, Contents(F(value, constraints), description))
}

/// Creates a  #(name, Contents(LF(value), description))
///
pub fn floats(
  called name: String,
  default value: List(Float),
  explained description: Description,
  satisfying constraints: List(Constraint(Float)),
) -> Flag {
  #(name, Contents(LF(value, constraints), description))
}

/// Creates a #(name, Contents(S(value), description))
///
pub fn string(
  called name: String,
  default value: String,
  explained description: Description,
  satisfying constraints: List(Constraint(String)),
) -> Flag {
  #(name, Contents(S(value, constraints), description))
}

/// Creates a #(name, Contents(LS(value), description))
///
pub fn strings(
  called name: String,
  default value: List(String),
  explained description: Description,
  satisfying constraints: List(Constraint(String)),
) -> Flag {
  #(name, Contents(LS(value, constraints), description))
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
  use contents <- result.then(access(flags, key))
  contents.value
  |> compute_flag(for: key, with: value)
  |> result.map(Contents(_, contents.description))
  |> result.map(map.insert(flags, key, _))
}

fn attempt_toggle_flag(in flags: Map, at key: String) -> Result(Map) {
  use contents <- result.then(access(flags, key))
  case contents.value {
    B(val) ->
      !val
      |> B
      |> Contents(contents.description)
      |> map.insert(into: flags, for: key)
      |> Ok()
    _ -> Error(no_value_flag_err(key))
  }
}

/// Gets the current Value for the associated flag
///
fn get_value(from flags: Map, for name: String) -> Result(Value) {
  use contents <- result.then(access(flags, name))
  Ok(contents.value)
}

fn access_type_error(name) {
  snag.new("cannot access non " <> name <> " flag as " <> name)
}

/// Gets the current value for the associated int flag
///
pub fn get_int(from flags: Map, for name: String) -> Result(Int) {
  use value <- result.then(get_value(flags, name))
  case value {
    I(val, _) -> Ok(val)
    _ -> snag.error("cannot acess non int flag as int")
  }
}

/// Gets the current value for the associated ints flag
///
pub fn get_ints(from flags: Map, for name: String) -> Result(List(Int)) {
  use value <- result.then(get_value(flags, name))
  case value {
    LI(val, _) -> Ok(val)
    _ -> snag.error(todo)
  }
}

/// Gets the current value for the associated bool flag
///
pub fn get_bool(from flags: Map, for name: String) -> Result(Bool) {
  use value <- result.then(get_value(flags, name))
  case value {
    B(val) -> Ok(val)
    _ -> snag.error(todo)
  }
}

/// Gets the current value for the associated string flag
///
pub fn get_string(from flags: Map, for name: String) -> Result(String) {
  use value <- result.then(get_value(flags, name))
  case value {
    S(val, _) -> Ok(val)
    _ -> snag.error(todo)
  }
}

/// Gets the current value for the associated strings flag
///
pub fn get_strings(from flags: Map, for name: String) -> Result(List(String)) {
  use value <- result.then(get_value(flags, name))
  case value {
    LS(val, _) -> Ok(val)
    _ -> snag.error(todo)
  }
}

/// Gets the current value for the associated int flag
///
pub fn get_float(from flags: Map, for name: String) -> Result(Float) {
  use value <- result.then(get_value(flags, name))
  case value {
    F(val, _) -> Ok(val)
    _ -> snag.error(todo)
  }
}

/// Gets the current value for the associated floats flag
///
pub fn get_floats(from flags: Map, for name: String) -> Result(List(Float)) {
  use value <- result.then(get_value(flags, name))
  case value {
    LF(val, _) -> Ok(val)
    _ -> snag.error(todo)
  }
}

/// Access the contents for the associated flag
///
fn access(flags: Map, name: String) -> Result(Contents) {
  map.get(flags, name)
  |> result.replace_error(undefined_flag_err(name))
}

fn apply_constraints(val: a, constraints: List(Constraint(a))) -> Result(a) {
  list.try_map(constraints, fn(c) { c(val) })
  |> result.replace(val)
}

fn apply_list_constraints(
  vals: List(a),
  constraints: List(Constraint(a)),
) -> Result(List(a)) {
  {
    use val <- list.try_map(vals)
    use c <- list.try_map(constraints)
    c(val)
  }
  |> result.replace(vals)
}

/// Computes the new flag value given the input and the expected flag type 
///
fn compute_flag(
  for name: String,
  with input: String,
  given default: Value,
) -> Result(Value) {
  case default {
    I(_, constraints) ->
      parse_int(name, input)
      |> result.then(apply_constraints(_, constraints))
      |> result.map(I(_, constraints))
    LI(_, constraints) ->
      parse_int_list(name, input)
      |> result.map(LI(_, constraints))
    F(_, constraints) ->
      parse_float(name, input)
      |> result.then(apply_constraints(_, constraints))
      |> result.map(F(_, constraints))
    LF(_, constraints) ->
      parse_float_list(name, input)
      |> result.then(apply_list_constraints(_, constraints))
      |> result.map(LF(_, constraints))
    S(_, constraints) ->
      parse_string(name, input)
      |> result.then(apply_constraints(_, constraints))
      |> result.map(S(_, constraints))
    LS(_, constraints) ->
      parse_string_list(name, input)
      |> result.then(apply_list_constraints(_, constraints))
      |> result.map(LS(_, constraints))
    B(_) ->
      parse_bool(name, input)
      |> result.map(B)
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
    I(_, _) -> "INT"
    B(_) -> "BOOL"
    F(_, _) -> "FLOAT"
    LF(_, _) -> "FLOAT_LIST"
    LI(_, _) -> "INT_LIST"
    LS(_, _) -> "STRING_LIST"
    S(_, _) -> "STRING"
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
