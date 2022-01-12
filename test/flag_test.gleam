import gleeunit/should
import glint.{CommandInput}
import glint/flag
import gleam/map

pub fn flag_default_test() {
  let args = ["arg1", "arg2"]
  let flags = flag.string("flag", "default")

  let flag_value_should_be_default = fn(in: CommandInput) {
    should.equal(in.args, args)

    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flags.value))
  }

  glint.new()
  |> glint.add_command(["cmd"], flag_value_should_be_default, [flags])
  |> glint.execute(["cmd", ..args])
  |> should.be_ok()
}

pub fn flag_value_test() {
  let args = ["arg1", "arg2"]
  let flags = flag.string("flag", "default")
  let flag_input = "-flag=flag_value"
  let flag_value_should_be_set = fn(in: CommandInput) {
    should.equal(in.args, args)

    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.StringFlag("flag_value")))
  }

  glint.new()
  |> glint.add_command(["cmd"], flag_value_should_be_set, [flags])
  |> glint.execute(["cmd", flag_input, ..args])
  |> should.be_ok()
}

pub fn int_flag_test() {
  // fails to parse input for flag as int, returns error
  let flags = flag.int("flag", 1)
  let flag_input = "-flag=X"

  glint.new()
  |> glint.add_command([], fn(_) { Nil }, [flags])
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int, sets value
  let flag_input = "-flag=10"
  let expect_flag_value_of_10 = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.IntFlag(10)))
  }

  glint.new()
  |> glint.add_command([], expect_flag_value_of_10, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn bool_flag_test() {
  // fails to parse input for flag as bool, returns error
  let flags = flag.bool("flag", True)
  let flag_input = "-flag=X"

  glint.new()
  |> glint.add_command([], fn(_) { Nil }, [flags])
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as bool, sets value
  let flag_input = "-flag=false"
  let expect_flag_value_of_false = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.BoolFlag(False)))
  }
  glint.new()
  |> glint.add_command([], expect_flag_value_of_false, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}
