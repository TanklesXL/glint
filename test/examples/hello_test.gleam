import examples/hello
import gleam/list
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

  assert hello.hello(tc.input, tc.caps, tc.repeat) == tc.expected
}

pub fn app_test() {
  assert glint.run(hello.app(), ["Joe", "Gleamlins", "--repeat=2", "--caps"])
    == Ok(glint.Out("HELLO, JOE AND GLEAMLINS!\nHELLO, JOE AND GLEAMLINS!"))
}
