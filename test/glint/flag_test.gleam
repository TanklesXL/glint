import gleeunit/should
import glint.{CommandInput}
import glint/flag
import gleam/map
import gleam/list
import gleam/string

pub fn update_flag_test() {
  let flags =
    [
      #("bflag", flag.new(flag.B)),
      #("sflag", flag.new(flag.S)),
      #("lsflag", flag.new(flag.LS)),
      #("iflag", flag.new(flag.I)),
      #("liflag", flag.new(flag.LI)),
      #("fflag", flag.new(flag.F)),
      #("lfflag", flag.new(flag.LF)),
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
  glint.new()
  |> glint.add(["cmd"], glint.cmd(fn(_) { Nil }))
  |> glint.execute(["--flag=1"])
  |> should.be_error()
}

pub fn flag_default_test() {
  let args = ["arg1", "arg2"]
  let flags = #(
    "flag",
    flag.new(
      flag.S
      |> flag.default("default"),
    ),
  )

  let flag_value_should_be_default = fn(in: CommandInput) {
    should.equal(in.args, args)

    in.flags
    |> map.get("flag")
    |> should.equal(Ok(flags.1))
  }

  glint.new()
  |> glint.add(
    ["cmd"],
    glint.cmd(flag_value_should_be_default)
    |> glint.flags([flags]),
  )
  |> glint.execute(["cmd", ..args])
  |> should.be_ok()
}

pub fn flag_value_test() {
  let args = ["arg1", "arg2"]
  let flags = #("flag", flag.new(flag.S))
  let flag_input = "--flag=flag_value"
  let flag_value_should_be_set = fn(in: CommandInput) {
    should.equal(in.args, args)

    in.flags
    |> flag.get_string("flag")
    |> should.equal(Ok("flag_value"))
  }

  glint.new()
  |> glint.add(
    ["cmd"],
    glint.cmd(flag_value_should_be_set)
    |> glint.flags([flags]),
  )
  |> glint.execute(["cmd", flag_input, ..args])
  |> should.be_ok()
}

pub fn int_flag_test() {
  let flags = #("flag", flag.new(flag.I))

  // fails to parse input for flag as int, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(_) { Nil })
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int, sets value
  let flag_input = "--flag=10"
  let expect_flag_value_of_10 = fn(in: CommandInput) {
    in.flags
    |> flag.get_int("flag")
    |> should.equal(Ok(10))
  }

  glint.new()
  |> glint.add(
    [],
    glint.cmd(expect_flag_value_of_10)
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn bool_flag_test() {
  let flags = #("flag", flag.new(flag.B))

  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(_) { Nil })
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as bool, sets value
  let flag_input = "--flag=false"
  let expect_flag_value_of_false = fn(in: CommandInput) {
    in.flags
    |> flag.get_bool("flag")
    |> should.equal(Ok(False))
  }
  glint.new()
  |> glint.add(
    [],
    glint.cmd(expect_flag_value_of_false)
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn strings_flag_test() {
  let flags = #("flag", flag.new(flag.LS))
  let flag_input = "--flag=val3,val4"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> flag.get_strings("flag")
    |> should.equal(Ok(["val3", "val4"]))
  }
  glint.new()
  |> glint.add(
    [],
    glint.cmd(expect_flag_value_list)
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn ints_flag_test() {
  let flags = #("flag", flag.new(flag.LI))

  // fails to parse input for flag as int list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(_) { Nil })
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int list, sets value
  let flag_input = "--flag=3,4"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> flag.get_ints("flag")
    |> should.equal(Ok([3, 4]))
  }
  glint.new()
  |> glint.add(
    [],
    glint.cmd(expect_flag_value_list)
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn float_flag_test() {
  let flags = #("flag", flag.new(flag.F))

  // fails to parse input for flag as float, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(_) { Nil })
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float, sets value
  let flag_input = "--flag=10.0"
  let expect_flag_value_of_10 = fn(in: CommandInput) {
    in.flags
    |> flag.get_float("flag")
    |> should.equal(Ok(10.0))
  }

  glint.new()
  |> glint.add(
    [],
    glint.cmd(expect_flag_value_of_10)
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn floats_flag_test() {
  let flags = #("flag", flag.new(flag.LF))

  // fails to parse input for flag as float list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(_) { Nil })
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float list, sets value
  let flag_input = "--flag=3.0,4.0"
  let expect_flag_value_list = fn(in: CommandInput) {
    in.flags
    |> flag.get_floats("flag")
    |> should.equal(Ok([3.0, 4.0]))
  }
  glint.new()
  |> glint.add(
    [],
    glint.cmd(expect_flag_value_list)
    |> glint.flags([flags]),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn global_flag_test() {
  let testcase = fn(vals: List(Float)) {
    fn(in: CommandInput) {
      in.flags
      |> flag.get_floats("flag")
      |> should.equal(Ok(vals))
    }
  }

  // set global flag, pass in  new value for flag
  glint.new()
  |> glint.with_global_flags([#("flag", flag.new(flag.LF))])
  |> glint.add(at: [], do: glint.cmd(testcase([3.0, 4.0])))
  |> glint.execute(["--flag=3.0,4.0"])
  |> should.be_ok()

  // set global flag and local flag, local flag should take priority
  glint.new()
  |> glint.with_global_flags([#("flag", flag.new(flag.LF))])
  |> glint.add(
    at: [],
    do: glint.cmd(testcase([1.0, 2.0]))
    |> glint.flag(
      "flag",
      flag.LF
      |> flag.default([1.0, 2.0])
      |> flag.new,
    ),
  )
  |> glint.execute([])
  |> should.be_ok()

  // set global flag and local flag, pass in new value for flag
  glint.new()
  |> glint.with_global_flags([
    #(
      "flag",
      flag.LF
      |> flag.default([3.0, 4.0])
      |> flag.new,
    ),
  ])
  |> glint.add(
    at: [],
    do: glint.cmd(testcase([5.0, 6.0]))
    |> glint.flag(
      "flag",
      flag.LF
      |> flag.default([1.0, 2.0])
      |> flag.new,
    ),
  )
  |> glint.execute(["--flag=5.0,6.0"])
  |> should.be_ok()
}

pub fn toggle_test() {
  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(_) { Nil })
    |> glint.flag("flag", flag.new(flag.B)),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // boolean flag is toggled, sets value to True
  let flag_input = "--flag"

  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(in: CommandInput) {
      in.flags
      |> flag.get_bool(for: "flag")
      |> should.equal(Ok(True))
    })
    |> glint.flag("flag", flag.new(flag.B)),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()

  // boolean flag with default of True is toggled, sets value to False
  let flag_input = "--flag"

  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(in: CommandInput) {
      in.flags
      |> flag.get_bool(for: "flag")
      |> should.equal(Ok(False))
    })
    |> glint.flag(
      "flag",
      flag.B
      |> flag.default(True)
      |> flag.new,
    ),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()

  // boolean flag without default toggled, sets value to True
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(in: CommandInput) {
      in.flags
      |> flag.get_bool(for: "flag")
      |> should.equal(Ok(True))
    })
    |> glint.flag("flag", flag.new(flag.B)),
  )
  |> glint.execute([flag_input])
  |> should.be_ok()

  // cannot toggle non-bool flag
  glint.new()
  |> glint.add(
    [],
    glint.cmd(fn(_) { Nil })
    |> glint.flag(
      "flag",
      flag.I
      |> flag.default(1)
      |> flag.new,
    ),
  )
  |> glint.execute([flag_input])
  |> should.be_error()
}

pub fn flags_help_test() {
  [
    #(
      "s",
      flag.new(flag.S)
      |> flag.desc("a string flag"),
    ),
    #(
      "i",
      flag.new(flag.I)
      |> flag.desc("an int flag"),
    ),
    #(
      "f",
      flag.new(flag.F)
      |> flag.desc("a float flag"),
    ),
  ]
  |> flag.build_map()
  |> flag.flags_help()
  |> list.sort(string.compare)
  |> should.equal([
    "--f=<FLOAT>\t\ta float flag", "--i=<INT>\t\tan int flag",
    "--s=<STRING>\t\ta string flag",
  ])
}
