import gleam/list
import gleeunit
import gleeunit/should
import glint
import hello

pub fn main() {
  gleeunit.main()
}

type TestCase {
  TestCase(input: List(String), caps: Bool, repeat: Int, expected: String)
}

pub fn hello_test() {
  use tc <- list.each([
    TestCase(["Rob"], False, 1, "Hello, Rob!"),
    TestCase(["Rob"], True, 1, "HELLO, ROB!"),
    TestCase(["Tony", "Maria"], True, 1, "HELLO, TONY AND MARIA!"),
    TestCase(
      ["Tony", "Maria", "Nadia"],
      True,
      1,
      "HELLO, TONY, MARIA AND NADIA!",
    ),
    TestCase(["Tony", "Maria"], False, 1, "Hello, Tony and Maria!"),
    TestCase(
      ["Tony", "Maria", "Nadia"],
      False,
      1,
      "Hello, Tony, Maria and Nadia!",
    ),
  ])

  let assert [head, ..rest] = tc.input
  hello.hello(head, rest, tc.caps, tc.repeat)
  |> should.equal(tc.expected)
}

pub fn app_test() {
  hello.app()
  |> glint.execute(["Joe", "Gleamlins"])
  |> should.equal(Ok(glint.Out("Hello, Joe and Gleamlins!")))
}
