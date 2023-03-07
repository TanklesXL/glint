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
