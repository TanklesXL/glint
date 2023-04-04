import glint/flag/constraint.{all, none_of, one_of}
import gleeunit/should
import glint/flag.{WithConstraint}
import gleam/list

pub fn one_of_test() {
  1
  |> constraint.one_of([1, 2, 3])
  |> should.equal(Ok(Nil))

  1
  |> constraint.one_of([2, 3, 4])
  |> should.be_error()
}

pub fn flag_one_of_none_of_test() {
  use test_case <- list.each([
    #(
      flag.int(
        "i",
        "",
        [WithConstraint(one_of([1, 2, 3])), WithConstraint(none_of([4, 5, 6]))],
      ),
      "1",
      "6",
    ),
    #(
      flag.ints(
        "li",
        "",
        [
          WithConstraint(
            [1, 2, 3]
            |> one_of
            |> all,
          ),
          WithConstraint(
            [4, 5, 6]
            |> none_of
            |> all,
          ),
        ],
      ),
      "1,1,1",
      "2,2,6",
    ),
    #(
      flag.float(
        "f",
        "",
        [
          WithConstraint(one_of([1.0, 2.0, 3.0])),
          WithConstraint(none_of([4.0, 5.0, 6.0])),
        ],
      ),
      "1.0",
      "6.0",
    ),
    #(
      flag.floats(
        "lf",
        "",
        [
          WithConstraint(
            [1.0, 2.0, 3.0]
            |> one_of()
            |> all,
          ),
          WithConstraint(
            [4.0, 5.0, 6.0]
            |> none_of()
            |> all,
          ),
        ],
      ),
      "3.0,2.0,1.0",
      "2.0,3.0,6.0",
    ),
    #(
      flag.string(
        "s",
        "",
        [
          WithConstraint(one_of(["t1", "t2", "t3"])),
          WithConstraint(none_of(["t4", "t5", "t6"])),
        ],
      ),
      "t3",
      "t4",
    ),
    #(
      flag.strings(
        "ls",
        "",
        [
          WithConstraint(
            ["t1", "t2", "t3"]
            |> one_of
            |> all,
          ),
          WithConstraint(
            ["t4", "t5", "t6"]
            |> none_of
            |> all,
          ),
        ],
      ),
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
