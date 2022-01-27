import gleeunit/should
import glint.{CommandInput}
import glint/flag
import gleam/map

pub fn update_flag_test() {
  let flags =
    [flag.string("sflag", "default"), flag.int("iflag", 0)]
    |> flag.build_map()

  // update non-existent flag fails
  flags
  |> flag.update_flags("--not_a_flag=hello")
  |> should.be_error()

  // update string flag succeeds
  flags
  |> flag.update_flags("--sflag=hello")
  |> should.be_ok()

  // updated int flag with non-int fails
  flags
  |> flag.update_flags("--iflag=hello")
  |> should.be_error()

  // updated int flag with int succeeds
  flags
  |> flag.update_flags("--iflag=1")
  |> should.be_ok()
}

pub fn unsupported_flag_test() {
  glint.new()
  |> glint.add_command(["cmd"], fn(_) { Nil }, [])
  |> glint.execute(["--flag=1"])
  |> should.be_error()
}

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
  let flag_input = "--flag=flag_value"
  let flag_value_should_be_set = fn(in: CommandInput) {
    should.equal(in.args, args)

    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.S("flag_value")))
  }

  glint.new()
  |> glint.add_command(["cmd"], flag_value_should_be_set, [flags])
  |> glint.execute(["cmd", flag_input, ..args])
  |> should.be_ok()
}

pub fn int_flag_test() {
  let flags = flag.int("flag", 1)

  // fails to parse input for flag as int, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add_command([], fn(_) { Nil }, [flags])
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int, sets value
  let flag_input = "--flag=10"
  let expect_flag_value_of_10 = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.I(10)))
  }

  glint.new()
  |> glint.add_command([], expect_flag_value_of_10, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn bool_flag_test() {
  let flags = flag.bool("flag", True)

  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add_command([], fn(_) { Nil }, [flags])
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as bool, sets value
  let flag_input = "--flag=false"
  let expect_flag_value_of_false = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.B(False)))
  }
  glint.new()
  |> glint.add_command([], expect_flag_value_of_false, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn string_list_flag_test() {
  let flags = flag.string_list("flag", ["val1", "val2"])
  let flag_input = "--flag=val3,val4"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.LS(["val3", "val4"])))
  }
  glint.new()
  |> glint.add_command([], expect_flag_value_list, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn int_list_flag_test() {
  let flags = flag.int_list("flag", [1, 2])

  // fails to parse input for flag as int list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new()
  |> glint.add_command([], fn(_) { Nil }, [flags])
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int list, sets value
  let flag_input = "--flag=3,4"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.LI([3, 4])))
  }
  glint.new()
  |> glint.add_command([], expect_flag_value_list, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn float_flag_test() {
  let flags = flag.float("flag", 1.0)

  // fails to parse input for flag as float, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add_command([], fn(_) { Nil }, [flags])
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float, sets value
  let flag_input = "--flag=10.0"
  let expect_flag_value_of_10 = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.F(10.0)))
  }

  glint.new()
  |> glint.add_command([], expect_flag_value_of_10, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn float_list_flag_test() {
  let flags = flag.float_list("flag", [1.0, 2.0])

  // fails to parse input for flag as float list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new()
  |> glint.add_command([], fn(_) { Nil }, [flags])
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float list, sets value
  let flag_input = "--flag=3.0,4.0"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flag.LF([3.0, 4.0])))
  }
  glint.new()
  |> glint.add_command([], expect_flag_value_list, [flags])
  |> glint.execute([flag_input])
  |> should.be_ok()
}
