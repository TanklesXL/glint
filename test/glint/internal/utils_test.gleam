import gleeunit/should
import glint/internal/utils

pub fn wordwrap_test() {
  "a b c"
  |> utils.wordwrap(3)
  |> should.equal(["a b", "c"])

  "a\nb\n\nc\n\n\nd\n\n\n\ne"
  |> utils.wordwrap(1)
  |> should.equal(["a", "b", "c\n", "d\n\n", "e"])
}
