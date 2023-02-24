import gleam/list
import gleam/string
import gleam/float
import gleam/int
import gleam/result
import gleam/set
import gleam/order.{Gt, Lt}
import snag.{Result}
import glint/flag.{Constraint}

pub fn one_of(allowed: List(a)) -> Constraint(a) {
  let allowed_set = set.from_list(allowed)
  fn(val: a) -> Result(Nil) {
    case set.contains(allowed_set, val) {
      True -> Ok(Nil)
      False ->
        "invalid flag value, must be one of: " <> {
          allowed
          |> list.map(fn(a) { "'" <> string.inspect(a) <> "'" })
          |> string.join(", ")
        }
        |> snag.error
    }
  }
}

pub fn int_compare(i: Int, f: fn(order.Order) -> Result(Nil)) -> Constraint(Int) {
  fn(val: Int) {
    val
    |> int.compare(i)
    |> f
  }
}

pub fn float_compare(
  fl: Float,
  f: fn(order.Order) -> Result(Nil),
) -> Constraint(Float) {
  fn(val: Float) {
    val
    |> float.compare(fl)
    |> f
  }
}

pub fn float_loose_compare(
  fl: Float,
  tolerance: Float,
  f: fn(order.Order) -> Result(Nil),
) -> Constraint(Float) {
  fn(val: Float) {
    val
    |> float.compare(fl)
    |> f
  }
}

pub fn in_int_range(from min: Int, to max: Int) -> Constraint(Int) {
  fn(val: Int) {
    [
      val
      |> int_compare(
        min,
        fn(o) {
          case o {
            Lt -> snag.error(todo)
            _ -> todo
          }
        },
      ),
      val
      |> int_compare(
        max,
        fn(o) {
          case o {
            Gt -> snag.error(todo)
            _ -> todo
          }
        },
      ),
    ]
    |> result.all
    |> result.replace(Nil)
  }
}

pub fn in_float_range(from min: Float, to max: Float) -> Constraint(Float) {
  fn(val: Float) {
    [
      val
      |> float_compare(
        min,
        fn(o) {
          case o {
            Lt -> snag.error(todo)
            _ -> todo
          }
        },
      ),
      val
      |> float_compare(
        max,
        fn(o) {
          case o {
            Gt -> snag.error(todo)
            _ -> todo
          }
        },
      ),
    ]
    |> result.all
    |> result.replace(Nil)
  }
}

pub fn loosely_in_float_range(
  from min: Float,
  to max: Float,
  with tolerance: Float,
) -> Constraint(Float) {
  fn(val: Float) {
    case
      float.loosely_compare(val, min, tolerance),
      float.loosely_compare(val, max, tolerance)
    {
      Lt, _ | _, Gt -> snag.error(todo)
      _, _ -> Ok(Nil)
    }
  }
}
