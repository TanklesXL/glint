import glint/flag/constraints
import gleeunit/should
import glint/flag
import gleam/option.{None}

pub fn one_of_test() {
  1
  |> constraints.one_of([1, 2, 3])
  |> should.equal(Ok(Nil))

  1
  |> constraints.one_of([2, 3, 4])
  |> should.be_error()
}

pub fn flag_constraints_test() {
  [flag.int("i", None, "", [constraints.one_of([1, 2, 3])])]
  |> flag.build_map()
  |> flag.update_flags("--i=1")
  |> should.be_ok
  |> flag.update_flags("--i=6")
  |> should.be_error

  [flag.ints("li", None, "", [constraints.one_of([1, 2, 3])])]
  |> flag.build_map()
  |> flag.update_flags("--li=1,1,1")
  |> should.be_ok
  |> flag.update_flags("--li=2,2,6")
  |> should.be_error

  [flag.float("f", None, "", [constraints.one_of([1.0, 2.0, 3.0])])]
  |> flag.build_map()
  |> flag.update_flags("--f=1.0")
  |> should.be_ok
  |> flag.update_flags("--f=6.0")
  |> should.be_error

  [flag.floats("lf", None, "", [constraints.one_of([1.0, 2.0, 3.0])])]
  |> flag.build_map()
  |> flag.update_flags("--lf=3.0,2.0,1.0")
  |> should.be_ok
  |> flag.update_flags("--lf=2.0,3.0,6.0")
  |> should.be_error

  [flag.string("s", None, "", [constraints.one_of(["t1", "t2", "t3"])])]
  |> flag.build_map()
  |> flag.update_flags("--s=t3")
  |> should.be_ok
  |> flag.update_flags("--s=t4")
  |> should.be_error

  [flag.strings("ls", None, "", [constraints.one_of(["t1", "t2", "t3"])])]
  |> flag.build_map()
  |> flag.update_flags("--ls=t3,t2,t1")
  |> should.be_ok
  |> flag.update_flags("--ls=t2,t4,t1")
  |> should.be_error
}
