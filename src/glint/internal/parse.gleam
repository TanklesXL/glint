import gleam/list
import gleam/result
import gleam/string
import lenient_parse

pub type ParseError {
  FailedToParse(value: String, kind: String)
}

pub fn string(s: String) -> Result(String, ParseError) {
  Ok(s)
}

pub fn strings(s: String) -> Result(List(String), ParseError) {
  s
  |> string.split(",")
  |> Ok
}

pub fn int(s: String) -> Result(Int, ParseError) {
  s
  |> lenient_parse.to_int
  |> result.replace_error(FailedToParse(s, "int"))
}

pub fn ints(s: String) -> Result(List(Int), ParseError) {
  use s <- list.try_map(string.split(s, ","))
  s
  |> lenient_parse.to_int
  |> result.replace_error(FailedToParse(s, "int list"))
}

pub fn float(s: String) -> Result(Float, ParseError) {
  s
  |> lenient_parse.to_float
  |> result.replace_error(FailedToParse(s, "float"))
}

pub fn floats(s: String) -> Result(List(Float), ParseError) {
  use s <- list.try_map(string.split(s, ","))
  s
  |> lenient_parse.to_float
  |> result.replace_error(FailedToParse(s, "float list"))
}

pub fn bool(s: String) -> Result(Bool, ParseError) {
  case string.lowercase(s) {
    "true" | "t" | "1" -> Ok(True)
    "false" | "f" | "0" -> Ok(False)
    _ -> Error(FailedToParse(s, "bool"))
  }
}

pub fn error_to_string(error: ParseError) -> String {
  "failed to parse value '" <> error.value <> "' as " <> error.kind
}
