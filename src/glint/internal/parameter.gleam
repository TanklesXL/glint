import gleam/option
import gleam/result

pub type Parameter(kind, error) {
  Parameter(
    name: String,
    description: String,
    parser: fn(String) -> Result(kind, error),
    value: option.Option(kind),
  )
}

pub fn add_constraint(
  p: Parameter(kind, error),
  constraint: fn(kind) -> Result(kind, error),
) -> Parameter(kind, error) {
  Parameter(
    ..p,
    parser: fn(s) {
      s
      |> p.parser
      |> result.try(constraint)
    },
  )
}
