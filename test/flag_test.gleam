import gleeunit/should
import glint.{CommandInput}
import glint/flag.{B, F, I, LF, LI, LS, S}
import gleam/map

pub fn update_flag_test() {
  let flags =
    [
      flag.bool("bflag", False, ""),
      flag.string("sflag", "default", ""),
      flag.strings("lsflag", ["a", "b", "c"], ""),
      flag.int("iflag", 0, ""),
      flag.ints("liflag", [0, 1, 2, 3], ""),
      flag.float("fflag", 1.0, ""),
      flag.floats("lfflag", [0.0, 1.0, 2.0], ""),
    ]
    |> flag.build_map()

  // update non-existent flag fails
  flags
  |> flag.update_flags("--not_a_flag=hello")
  |> should.be_error()

  // update bool flag succeeds
  flags
  |> flag.update_flags("--bflag=true")
  |> should.be_ok()

  // update bool flag with non-bool value fails
  flags
  |> flag.update_flags("--bflag=zzz")
  |> should.be_error()

  // toggle bool flag succeeds
  flags
  |> flag.update_flags("--bflag")
  |> should.be_ok()

  // toggle non-bool flag succeeds
  flags
  |> flag.update_flags("--sflag")
  |> should.be_error()

  // update string flag succeeds
  flags
  |> flag.update_flags("--sflag=hello")
  |> should.be_ok()

  // update int flag with non-int fails
  flags
  |> flag.update_flags("--iflag=hello")
  |> should.be_error()

  // update int flag with int succeeds
  flags
  |> flag.update_flags("--iflag=1")
  |> should.be_ok()

  // update int list flag with int list succeeds
  flags
  |> flag.update_flags("--liflag=1,2,3")
  |> should.be_ok()

  // update int list flag with non int list succeeds
  flags
  |> flag.update_flags("--liflag=a,b,c")
  |> should.be_error()

  // update float flag with non-int fails
  flags
  |> flag.update_flags("--fflag=hello")
  |> should.be_error()

  // update float flag with int succeeds
  flags
  |> flag.update_flags("--fflag=1.0")
  |> should.be_ok()

  // update float list flag with int list succeeds
  flags
  |> flag.update_flags("--lfflag=1.0,2.0,3.0")
  |> should.be_ok()

  // update float list flag with non int list succeeds
  flags
  |> flag.update_flags("--lfflag=a,b,c")
  |> should.be_error()
}

pub fn unsupported_flag_test() {
  glint.new([])
  |> glint.add_command(["cmd"], fn(_) { Nil }, [], "")
  |> glint.execute(["--flag=1"])
  |> should.be_error()
}

pub fn flag_default_test() {
  let args = ["arg1", "arg2"]
  let flags = flag.string("flag", "default", "")

  let flag_value_should_be_default = fn(in: CommandInput) {
    should.equal(in.args, args)

    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flags.1))
  }

  glint.new([])
  |> glint.add_command(["cmd"], flag_value_should_be_default, [flags], "")
  |> glint.execute(["cmd", ..args])
  |> should.be_ok()
}

pub fn flag_value_test() {
  let args = ["arg1", "arg2"]
  let flags = flag.string("flag", "default", "")
  let flag_input = "--flag=flag_value"
  let flag_value_should_be_set = fn(in: CommandInput) {
    should.equal(in.args, args)

    in.flags
    |> flag.get_value("flag")
    |> should.equal(Ok(S("flag_value")))
  }

  glint.new([])
  |> glint.add_command(["cmd"], flag_value_should_be_set, [flags], "")
  |> glint.execute(["cmd", flag_input, ..args])
  |> should.be_ok()
}

pub fn int_flag_test() {
  let flags = flag.int("flag", 1, "")

  // fails to parse input for flag as int, returns error
  let flag_input = "--flag=X"
  glint.new([])
  |> glint.add_command([], fn(_) { Nil }, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int, sets value
  let flag_input = "--flag=10"
  let expect_flag_value_of_10 = fn(in: CommandInput) {
    in.flags
    |> flag.get_value("flag")
    |> should.equal(Ok(I(10)))
  }

  glint.new([])
  |> glint.add_command([], expect_flag_value_of_10, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn bool_flag_test() {
  let flags = flag.bool("flag", True, "")

  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  glint.new([])
  |> glint.add_command([], fn(_) { Nil }, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as bool, sets value
  let flag_input = "--flag=false"
  let expect_flag_value_of_false = fn(in: CommandInput) {
    in.flags
    |> flag.get_value("flag")
    |> should.equal(Ok(flag.B(False)))
  }
  glint.new([])
  |> glint.add_command([], expect_flag_value_of_false, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn strings_flag_test() {
  let flags = flag.strings("flag", ["val1", "val2"], "")
  let flag_input = "--flag=val3,val4"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> flag.get_value("flag")
    |> should.equal(Ok(LS(["val3", "val4"])))
  }
  glint.new([])
  |> glint.add_command([], expect_flag_value_list, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn ints_flag_test() {
  let flags = flag.ints("flag", [1, 2], "")

  // fails to parse input for flag as int list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new([])
  |> glint.add_command([], fn(_) { Nil }, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int list, sets value
  let flag_input = "--flag=3,4"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> flag.get_value("flag")
    |> should.equal(Ok(LI([3, 4])))
  }
  glint.new([])
  |> glint.add_command([], expect_flag_value_list, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn float_flag_test() {
  let flags = flag.float("flag", 1.0, "")

  // fails to parse input for flag as float, returns error
  let flag_input = "--flag=X"
  glint.new([])
  |> glint.add_command([], fn(_) { Nil }, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float, sets value
  let flag_input = "--flag=10.0"
  let expect_flag_value_of_10 = fn(in: CommandInput) {
    in.flags
    |> flag.get_value("flag")
    |> should.equal(Ok(F(10.0)))
  }

  glint.new([])
  |> glint.add_command([], expect_flag_value_of_10, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn floats_flag_test() {
  let flags = flag.floats("flag", [1.0, 2.0], "")

  // fails to parse input for flag as float list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new([])
  |> glint.add_command([], fn(_) { Nil }, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float list, sets value
  let flag_input = "--flag=3.0,4.0"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> flag.get_value("flag")
    |> should.equal(Ok(LF([3.0, 4.0])))
  }
  glint.new([])
  |> glint.add_command([], expect_flag_value_list, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn global_flag_test() {
  let testcase = fn(vals: List(Float)) {
    fn(in: CommandInput) {
      in.flags
      |> flag.get_value("flag")
      |> should.equal(Ok(LF(vals)))
    }
  }

  // set global flag, pass in  new value for flag
  glint.new([flag.floats("flag", [1.0, 2.0], "")])
  |> glint.add_command(
    at: [],
    with: [],
    do: testcase([3.0, 4.0]),
    described: "",
  )
  |> glint.execute(["--flag=3.0,4.0"])
  |> should.be_ok()

  // set global flag and local flag, local flag should take priority
  glint.new([flag.floats("flag", [3.0, 4.0], "")])
  |> glint.add_command(
    at: [],
    with: [flag.floats("flag", [1.0, 2.0], "")],
    do: testcase([1.0, 2.0]),
    described: "",
  )
  |> glint.execute([])
  |> should.be_ok()

  // set global flag and local flag, pass in new value for flag
  glint.new([flag.floats("flag", [3.0, 4.0], "")])
  |> glint.add_command(
    at: [],
    with: [flag.floats("flag", [1.0, 2.0], "")],
    do: testcase([5.0, 6.0]),
    described: "",
  )
  |> glint.execute(["--flag=5.0,6.0"])
  |> should.be_ok()
}

pub fn toggle_test() {
  let flags = flag.bool("flag", False, "")

  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  glint.new([])
  |> glint.add_command([], fn(_) { Nil }, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_error()

  // boolean flag is toggle, sets value to false
  let flag_input = "--flag"
  let expect_flag_value_of_true = fn(in: CommandInput) {
    in.flags
    |> flag.get_value(for: "flag")
    |> should.equal(Ok(B(True)))
  }

  glint.new([])
  |> glint.add_command([], expect_flag_value_of_true, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_ok()

  let flags = flag.int("flag", 1, "")

  // cannot toggle non-bool flag
  let flag_input = "--flag"
  glint.new([])
  |> glint.add_command([], fn(_) { Nil }, [flags], "")
  |> glint.execute([flag_input])
  |> should.be_error()
}

pub fn flags_help_test() {
  [
    flag.string("string", "", "a string flag"),
    flag.int("int", 0, "an int flag"),
    flag.float("float", 0.0, "a float flag"),
  ]
  |> flag.build_map()
  |> flag.flags_help()
  |> should.equal(
    "--float=<FLOAT>\t\ta float flag
\t--int=<INT>\t\tan int flag
\t--string=<STRING>\t\ta string flag",
  )
}
