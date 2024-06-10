import gleam/int
import gleam/list
import gleam/string

/// Returns the length of the longest string in the list.
///
pub fn max_string_length(strings: List(String)) -> Int {
  use max, f <- list.fold(strings, 0)

  f
  |> string.length
  |> int.max(max)
}

/// Wraps the given string so that no lines exceed the given width. Newlines in
/// the input string are retained.
///
pub fn wordwrap(s: String, max_width: Int) -> List(String) {
  use line <- list.flat_map(string.split(s, "\n"))

  line
  |> string.split(" ")
  |> do_wordwrap(max_width, "", [])
}

fn do_wordwrap(
  tokens: List(String),
  max_width: Int,
  line: String,
  lines: List(String),
) -> List(String) {
  case tokens {
    // Handle the next token
    [token, ..tokens] -> {
      let token_length = string.length(token)
      let line_length = string.length(line)

      case line, line_length + 1 + token_length <= max_width {
        // When the current line is empty the next token always goes on it
        // regardless of its length
        "", _ -> do_wordwrap(tokens, max_width, token, lines)

        // Add the next token to the current line if it fits
        _, True -> do_wordwrap(tokens, max_width, line <> " " <> token, lines)

        // Start a new line with the next token as it exceeds the max width if
        // added to the current line
        _, False -> do_wordwrap(tokens, max_width, token, [line, ..lines])
      }
    }

    // There are no more more tokens, so add the current line to the result if
    // it's not empty
    [] if line == "" -> list.reverse(lines)
    [] -> list.reverse([line, ..lines])
  }
}
