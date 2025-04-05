import examples/hello
import gleam/list
import gleeunit/should
import glint

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

  hello.hello(tc.input, tc.caps, tc.repeat)
  |> should.equal(tc.expected)
}

pub fn app_test() {
  use output <- glint.run_and_handle(hello.app(), [
    "Joe", "Gleamlins", "--repeat=2", "--caps",
  ])
  should.equal(output, "HELLO, JOE AND GLEAMLINS!\nHELLO, JOE AND GLEAMLINS!")
}
