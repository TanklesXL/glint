import gleam/bool
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
  use <- bool.guard(s == "", [])
  use line <- list.flat_map(space_split_lines(s))
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

    // There are no more tokens so return the final result, adding the current
    // line to it if it's not empty
    [] if line == "" -> list.reverse(lines)
    [] -> list.reverse([line, ..lines])
  }
}

pub fn space_split_lines(s: String) -> List(String) {
  { s |> string.to_graphemes |> do_space_split_lines(#([], False)) }.0
}

fn do_space_split_lines(
  ls: List(String),
  acc: #(List(String), Bool),
) -> #(List(String), Bool) {
  case ls, acc.0, acc.1 {
    [], _, _ -> #(list.reverse(acc.0), acc.1)

    ["\n", "\n", ..rest], [], True -> do_space_split_lines(rest, #([], True))

    ["\n", "\n", ..rest], [s, ..accs], True ->
      do_space_split_lines(["\n", ..rest], #([s <> "\n", ..accs], True))

    ["\n", "\n", ..rest], _, False -> do_space_split_lines(rest, #(acc.0, True))

    ["\n", ..rest], [], True -> do_space_split_lines(rest, #([], True))

    ["\n", ..rest], [s, ..accs], True ->
      do_space_split_lines(rest, #([s <> "\n", ..accs], True))

    ["\n", ..rest], [], False -> do_space_split_lines(rest, #([], False))

    ["\n", ..rest], [s, ..accs], False ->
      do_space_split_lines(rest, #([s <> " ", ..accs], False))

    [c, ..rest], _, True -> do_space_split_lines(rest, #([c, ..acc.0], False))

    [c, ..rest], [], False -> do_space_split_lines(rest, #([c], False))

    [c, ..rest], [s, ..accs], False ->
      do_space_split_lines(rest, #([s <> c, ..accs], False))
  }
}
