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
  use line <- list.flat_map(space_single_newlines_split_multi_newlines(s))
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

pub fn space_single_newlines_split_multi_newlines(s: String) -> List(String) {
  { s |> string.to_graphemes |> do_split_first_newlines(#([], False)) }.0
}

fn do_split_first_newlines(
  ls: List(String),
  acc: #(List(String), Bool),
) -> #(List(String), Bool) {
  case ls {
    [] -> #(list.reverse(acc.0), acc.1)

    ["\n", "\n", ..rest] if acc.1 -> {
      case acc.0 {
        [] -> do_split_first_newlines(rest, #([], True))
        [s, ..accs] ->
          do_split_first_newlines(["\n", ..rest], #([s <> "\n", ..accs], True))
      }
    }

    ["\n", "\n", ..rest] -> do_split_first_newlines(rest, #(acc.0, True))

    ["\n", ..rest] if acc.1 -> {
      case acc.0 {
        [] -> do_split_first_newlines(rest, #([], True))
        [s, ..accs] ->
          do_split_first_newlines(rest, #([s <> "\n", ..accs], True))
      }
    }
    ["\n", ..rest] -> {
      case acc.0 {
        [] -> do_split_first_newlines(rest, #([], False))
        [s, ..accs] ->
          do_split_first_newlines(rest, #([s <> " ", ..accs], False))
      }
    }

    [c, ..rest] if acc.1 ->
      do_split_first_newlines(rest, #([c, ..acc.0], False))

    [c, ..rest] ->
      case acc.0 {
        [] -> do_split_first_newlines(rest, #([c], False))
        [s, ..accs] -> do_split_first_newlines(rest, #([s <> c, ..accs], False))
      }
  }
}
