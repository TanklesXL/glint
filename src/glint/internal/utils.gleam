import gleam/int
import gleam/list
import gleam/string

/// Returns the length of the longest string in the list.
///
pub fn max_string_length(strings: List(String)) -> Int {
  strings |> list.fold(0, fn(max, f) { f |> string.length |> int.max(max) })
}

/// Wraps the given string so that no lines exceed the given width. Newlines in
/// the input string are retained.
///
pub fn wordwrap(s: String, max_width: Int) -> List(String) {
  s
  |> string.split("\n")
  |> list.map(fn(s) {
    s
    |> string.split(" ")
    |> do_wordwrap(max_width, "", [])
  })
  |> list.flatten
}

fn do_wordwrap(
  tokens: List(String),
  max_width: Int,
  current_line: String,
  lines: List(String),
) -> List(String) {
  case tokens {
    [] ->
      case current_line {
        "" -> lines
        _ -> [current_line, ..lines]
      }
      |> list.reverse

    [token, ..new_tokens] -> {
      let line_length = string.length(current_line)
      let token_length = string.length(token)

      case line_length {
        0 -> do_wordwrap(new_tokens, max_width, token, lines)
        _ ->
          case line_length + 1 + token_length <= max_width {
            True -> {
              let current_line = current_line <> " " <> token
              do_wordwrap(new_tokens, max_width, current_line, lines)
            }

            False -> do_wordwrap(tokens, max_width, "", [current_line, ..lines])
          }
      }
    }
  }
}
