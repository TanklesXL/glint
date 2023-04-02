import gleam/list
import gleam/string
import gleam/set
import snag.{Result}
import glint/flag.{Constraint}

pub fn one_of(allowed: List(a)) -> Constraint(a) {
  let allowed_set = set.from_list(allowed)
  fn(val: a) -> Result(Nil) {
    case set.contains(allowed_set, val) {
      True -> Ok(Nil)
      False ->
        "invalid value '" <> string.inspect(val) <> "', must be one of: [" <> {
          allowed
          |> list.map(fn(a) { "'" <> string.inspect(a) <> "'" })
          |> string.join(", ") <> "]"
        }
        |> snag.error
    }
  }
}

pub fn none_of(disallowed: List(a)) -> Constraint(a) {
  let disallowed_set = set.from_list(disallowed)
  fn(val: a) -> Result(Nil) {
    case set.contains(disallowed_set, val) {
      False -> Ok(Nil)
      True ->
        "invalid value '" <> string.inspect(val) <> "', must not be one of: [" <> {
          disallowed
          |> list.map(fn(a) { "'" <> string.inspect(a) <> "'" })
          |> string.join(", ") <> "]"
        }
        |> snag.error
    }
  }
}
