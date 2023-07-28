import gleeunit
import gleeunit/should
import hello
import gleam/list

pub fn main() {
  gleeunit.main()
}

type TestCase {
  TestCase(input: List(String), caps: Bool, repeat: Int, expected: String)
}

pub fn hello_test() {
  use tc <- list.each([
    TestCase([], False, 1, "Hello, Joe!"),
    TestCase(["Rob"], False, 1, "Hello, Rob!"),
    TestCase([], True, 1, "HELLO, JOE!"),
    TestCase([], True, 2, "HELLO, JOE!\nHELLO, JOE!"),
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
  hello.hello(tc.input, tc.caps, tc.repeat)
  |> should.equal(tc.expected)
}
