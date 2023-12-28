import gleam/list
import gleam/result
import gleam/string
import gleam/set
import snag.{type Result}

/// Constraint type for verifying flag values
///
pub type Constraint(a) =
  fn(a) -> Result(Nil)

/// one_of returns a Constraint that ensures the parsed flag value is
/// one of the allowed values.
///
pub fn one_of(allowed: List(a)) -> Constraint(a) {
  let allowed_set = set.from_list(allowed)
  fn(val: a) -> Result(Nil) {
    case set.contains(allowed_set, val) {
      True -> Ok(Nil)
      False ->
        snag.error(
          "invalid value '"
          <> string.inspect(val)
          <> "', must be one of: ["
          <> {
            allowed
            |> list.map(fn(a) { "'" <> string.inspect(a) <> "'" })
            |> string.join(", ")
          }
          <> "]",
        )
    }
  }
}

/// none_of returns a Constraint that ensures the parsed flag value is not one of the disallowed values.
///
pub fn none_of(disallowed: List(a)) -> Constraint(a) {
  let disallowed_set = set.from_list(disallowed)
  fn(val: a) -> Result(Nil) {
    case set.contains(disallowed_set, val) {
      False -> Ok(Nil)
      True ->
        snag.error(
          "invalid value '"
          <> string.inspect(val)
          <> "', must not be one of: ["
          <> {
            {
              disallowed
              |> list.map(fn(a) { "'" <> string.inspect(a) <> "'" })
              |> string.join(", ")
              <> "]"
            }
          },
        )
    }
  }
}

/// each is a convenience function for applying a Constraint(a) to a List(a).
/// This is useful because the default behaviour for constraints on lists is that they will apply to the list as a whole.
/// 
/// For example, to apply one_of to all items in a `List(Int)`:
/// ```gleam
/// [1, 2, 3, 4] |> one_of |> each
/// ```
pub fn each(constraint: Constraint(a)) -> Constraint(List(a)) {
  fn(l: List(a)) -> Result(Nil) {
    l
    |> list.try_map(constraint)
    |> result.replace(Nil)
  }
}
