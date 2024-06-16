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

    // There are no more tokens so return the final result, adding the current
    // line to it if it's not empty
    [] if line == "" -> list.reverse(lines)
    [] -> list.reverse([line, ..lines])
  }
}

pub fn to_spaced_indented_string(
  data: List(a),
  indent_width: Int,
  f: fn(a) -> #(String, Bool),
) -> String {
  let #(content, wrapped) = {
    use acc, h <- list.fold(data, #([], False))
    let #(content, wrapped) = f(h)
    #(
      [
        string.append("\n" <> string.repeat(" ", indent_width), content),
        ..acc.0
      ],
      acc.1 || wrapped,
    )
  }

  let joiner = case wrapped {
    True -> "\n"
    False -> ""
  }

  content |> list.sort(string.compare) |> string.join(joiner)
}

pub fn help_content_to_wrapped_string(
  left: String,
  right: String,
  left_length: Int,
  min_left_width: Int,
  max_output_width: Int,
  indent_width: Int,
) -> #(String, Bool) {
  let left_formatted = string.pad_right(left, left_length, " ")

  let right_width =
    max_output_width
    |> int.subtract(left_length + indent_width)
    |> int.max(min_left_width)

  let lines = wordwrap(right, right_width)

  let wrapped = case lines {
    [] | [_] -> False
    _ -> True
  }

  let right_formatted =
    string.join(lines, "\n" <> string.repeat(" ", indent_width + left_length))

  #(left_formatted <> right_formatted, wrapped)
}
