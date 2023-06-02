import glint/flag/constraint.{each, none_of, one_of}
import gleeunit/should
import glint/flag
import gleam/list

pub fn one_of_test() {
  1
  |> one_of([1, 2, 3])
  |> should.equal(Ok(Nil))

  1
  |> one_of([2, 3, 4])
  |> should.be_error()

  [1, 2, 3]
  |> {
    [5, 4, 3, 2, 1]
    |> one_of
    |> each
  }
  |> should.equal(Ok(Nil))

  [1, 6, 3]
  |> {
    [5, 4, 3, 2, 1]
    |> one_of
    |> each
  }
  |> should.be_error()
}

pub fn none_of_test() {
  1
  |> constraint.none_of([1, 2, 3])
  |> should.be_error

  1
  |> constraint.none_of([2, 3, 4])
  |> should.equal(Ok(Nil))

  [1, 2, 3]
  |> {
    [4, 5, 6, 7, 8]
    |> none_of
    |> each
  }
  |> should.equal(Ok(Nil))

  [1, 6, 3]
  |> {
    [4, 5, 6, 7, 8]
    |> none_of
    |> each
  }
  |> should.be_error()
}

pub fn flag_one_of_none_of_test() {
  use test_case <- list.each([
    #(
      "i",
      flag.I
      |> flag.new
      |> flag.constraint(one_of([1, 2, 3]))
      |> flag.constraint(none_of([4, 5, 6]))
      |> flag.build,
      "1",
      "6",
    ),
    #(
      "li",
      flag.LI
      |> flag.new
      |> flag.constraint(
        [1, 2, 3]
        |> one_of
        |> each,
      )
      |> flag.constraint(
        [4, 5, 6]
        |> none_of
        |> each,
      )
      |> flag.build,
      "1,1,1",
      "2,2,6",
    ),
    #(
      "f",
      flag.F
      |> flag.new
      |> flag.constraint(one_of([1.0, 2.0, 3.0]))
      |> flag.constraint(none_of([4.0, 5.0, 6.0]))
      |> flag.build,
      "1.0",
      "6.0",
    ),
    #(
      "lf",
      flag.LF
      |> flag.new
      |> flag.constraint(
        [1.0, 2.0, 3.0]
        |> one_of()
        |> each,
      )
      |> flag.constraint(
        [4.0, 5.0, 6.0]
        |> none_of()
        |> each,
      )
      |> flag.build,
      "3.0,2.0,1.0",
      "2.0,3.0,6.0",
    ),
    #(
      "s",
      flag.S
      |> flag.new
      |> flag.constraint(one_of(["t1", "t2", "t3"]))
      |> flag.constraint(none_of(["t4", "t5", "t6"]))
      |> flag.build,
      "t3",
      "t4",
    ),
    #(
      "ls",
      flag.LS
      |> flag.new
      |> flag.constraint(
        ["t1", "t2", "t3"]
        |> one_of
        |> each,
      )
      |> flag.constraint(
        ["t4", "t5", "t6"]
        |> none_of
        |> each,
      )
      |> flag.build,
      "t3,t2,t1",
      "t2,t4,t1",
    ),
  ])

  let test_flag_name = test_case.0
  let test_flag = test_case.1
  let success = test_case.2
  let failure = test_case.3

  let input_flag = "--" <> test_flag_name <> "="

  [#(test_flag_name, test_flag)]
  |> flag.build_map()
  |> flag.update_flags(input_flag <> success)
  |> should.be_ok

  [#(test_flag_name, test_flag)]
  |> flag.build_map()
  |> flag.update_flags(input_flag <> failure)
  |> should.be_error
}
