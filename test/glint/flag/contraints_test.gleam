import glint/flag/constraints.{one_of}
import gleeunit/should
import glint/flag
import gleam/option.{None}
import gleam/list

pub fn one_of_test() {
  1
  |> constraints.one_of([1, 2, 3])
  |> should.equal(Ok(Nil))

  1
  |> constraints.one_of([2, 3, 4])
  |> should.be_error()
}

pub fn flag_constraints_test() {
  use test_case <- list.each([
    #(flag.int("i", None, "", [one_of([1, 2, 3])]), "1", "6"),
    #(flag.ints("li", None, "", [one_of([1, 2, 3])]), "1,1,1", "2,2,6"),
    #(flag.float("f", None, "", [one_of([1.0, 2.0, 3.0])]), "1.0", "6.0"),
    #(
      flag.floats("lf", None, "", [one_of([1.0, 2.0, 3.0])]),
      "3.0,2.0,1.0",
      "2.0,3.0,6.0",
    ),
    #(
      flag.string("s", None, "", [constraints.one_of(["t1", "t2", "t3"])]),
      "t3",
      "t4",
    ),
    #(
      flag.strings("ls", None, "", [constraints.one_of(["t1", "t2", "t3"])]),
      "t3,t2,t1",
      "t2,t4,t1",
    ),
  ])

  let test_flag = test_case.0
  let success = test_case.1
  let failure = test_case.2

  let input_flag = "--" <> test_flag.0 <> "="

  [test_flag]
  |> flag.build_map()
  |> flag.update_flags(input_flag <> success)
  |> should.be_ok

  [test_flag]
  |> flag.build_map()
  |> flag.update_flags(input_flag <> failure)
  |> should.be_error
}
