import gleeunit/should
import glint/internal/utils

pub fn wordwrap_test() {
  "a b c"
  |> utils.wordwrap(3)
  |> should.equal(["a b", "c"])
}
