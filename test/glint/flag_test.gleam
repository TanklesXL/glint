import gleeunit/should
import glint
import glint/flag
import gleam/list

pub fn update_flag_test() {
  let flags =
    [
      #("bflag", flag.build(flag.bool())),
      #("sflag", flag.build(flag.string())),
      #("lsflag", flag.build(flag.strings())),
      #("iflag", flag.build(flag.int())),
      #("liflag", flag.build(flag.ints())),
      #("fflag", flag.build(flag.float())),
      #("lfflag", flag.build(flag.floats())),
    ]
    |> list.fold(flag.flags(), fn(flags, t) { flag.insert(flags, t.0, t.1) })

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
  |> glint.add(["cmd"], glint.command(fn(_, _, _) { Nil }))
  |> glint.execute(["--flag=1"])
  |> should.be_error()
}

pub fn flag_default_test() {
  let args = ["arg1", "arg2"]
  let flag = #(
    "flag",
    flag.string()
      |> flag.default("default"),
  )

  glint.new()
  |> glint.add(["cmd"], {
    use flag_ <- glint.flag(flag.0, flag.1)
    use _, unnamed, flags <- glint.command()
    should.equal(args, unnamed)

    flag_(flags)
    |> should.equal(Ok("default"))
  })
  |> glint.execute(["cmd", ..args])
  |> should.be_ok()
}

pub fn flag_value_test() {
  let args = ["arg1", "arg2"]
  let flag = #("flag", flag.string())
  let flag_input = "--flag=flag_value"
  let flag_value_should_be_set = {
    use flag_ <- glint.flag(flag.0, flag.1)
    use _, in_args, flags <- glint.command()
    should.equal(in_args, args)

    flag_(flags)
    |> should.equal(Ok("flag_value"))
  }

  glint.new()
  |> glint.add(["cmd"], flag_value_should_be_set)
  |> glint.execute(["cmd", flag_input, ..args])
  |> should.be_ok()
}

pub fn int_flag_test() {
  let flags = #("flag", flag.int())

  // fails to parse input for flag as int, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add(
    [],
    glint.flag(flags.0, flags.1, fn(_flag) {
      glint.command(fn(_, _, _) { Nil })
    }),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int, sets value
  let flag_input = "--flag=10"
  let expect_flag_value_of_10 = {
    use flag_ <- glint.flag(flags.0, flags.1)
    use _, _, flags <- glint.command()
    flag_(flags)
    |> should.equal(Ok(10))
  }

  glint.new()
  |> glint.add([], expect_flag_value_of_10)
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn bool_flag_test() {
  let flag = #("flag", flag.bool())

  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add(
    [],
    glint.flag(flag.0, flag.1, fn(_flag) { glint.command(fn(_, _, _) { Nil }) }),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as bool, sets value
  let flag_input = "--flag=false"
  let expect_flag_value_of_false = fn(flag) {
    glint.command(fn(_, _, flags) {
      flag(flags)
      |> should.equal(Ok(False))
    })
  }

  glint.new()
  |> glint.add([], glint.flag(flag.0, flag.1, expect_flag_value_of_false))
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn strings_flag_test() {
  let flags = #("flag", flag.strings())
  let flag_input = "--flag=val3,val4"
  let expect_flag_value_list = fn(flag) {
    glint.command(fn(_, _, flags) {
      flag(flags)
      |> should.equal(Ok(["val3", "val4"]))
    })
  }
  glint.new()
  |> glint.add([], glint.flag(flags.0, flags.1, expect_flag_value_list))
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn ints_flag_test() {
  let flag = #("flag", flag.ints())

  // fails to parse input for flag as int list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new()
  |> glint.add(
    [],
    glint.flag(flag.0, flag.1, fn(_) { glint.command(fn(_, _, _) { Nil }) }),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as int list, sets value
  let flag_input = "--flag=3,4"
  let expect_flag_value_list = fn(flag) {
    glint.command(fn(_, _, flags) {
      flag(flags)
      |> should.equal(Ok([3, 4]))
    })
  }

  glint.new()
  |> glint.add([], glint.flag(flag.0, flag.1, expect_flag_value_list))
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn float_flag_test() {
  let flag = #("flag", flag.float())

  // fails to parse input for flag as float, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add([], {
    use _flag <- glint.flag(flag.0, flag.1)
    use _, _, _ <- glint.command()
    Nil
  })
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float, sets value
  let flag_input = "--flag=10.0"
  let expect_flag_value_of_10 = {
    use flag <- glint.flag(flag.0, flag.1)
    use _, _, flags <- glint.command()
    flag(flags)
    |> should.equal(Ok(10.0))
  }

  glint.new()
  |> glint.add([], expect_flag_value_of_10)
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn floats_flag_test() {
  let flag = #("flag", flag.floats())

  // fails to parse input for flag as float list, returns error
  let flag_input = "--flag=val3,val4"
  glint.new()
  |> glint.add([], {
    use _flag <- glint.flag(flag.0, flag.1)
    use _, _, _ <- glint.command()
    Nil
  })
  |> glint.execute([flag_input])
  |> should.be_error()

  // parses flag input as float list, sets value
  let flag_input = "--flag=3.0,4.0"
  let expect_flag_value_list = {
    use flag <- glint.flag(flag.0, flag.1)
    use _, _, flags <- glint.command
    flag(flags)
    |> should.equal(Ok([3.0, 4.0]))
  }
  glint.new()
  |> glint.add([], expect_flag_value_list)
  |> glint.execute([flag_input])
  |> should.be_ok()
}

pub fn global_flag_test() {
  let testcase = fn(vals: List(Float)) {
    use _, _, flags <- glint.command()
    flags
    |> flag.get_floats("flag")
    |> should.equal(Ok(vals))
  }

  // set global flag, pass in  new value for flag
  glint.new()
  |> glint.group_flag([], "flag", flag.floats())
  |> glint.add(at: [], do: testcase([3.0, 4.0]))
  |> glint.execute(["--flag=3.0,4.0"])
  |> should.be_ok()

  // set global flag and local flag, local flag should take priority
  glint.new()
  |> glint.group_flag([], "flag", flag.floats())
  |> glint.add(
    at: [],
    do: glint.flag(
      "flag",
      flag.floats()
        |> flag.default([1.0, 2.0]),
      fn(_) { testcase([1.0, 2.0]) },
    ),
  )
  |> glint.execute([])
  |> should.be_ok()

  // set global flag and local flag, pass in new value for flag
  glint.new()
  |> glint.group_flag(
    [],
    "flag",
    flag.floats()
      |> flag.default([3.0, 4.0]),
  )
  |> glint.add(at: [], do: {
    use _flag <- glint.flag(
      "flag",
      flag.floats()
        |> flag.default([1.0, 2.0]),
    )

    testcase([5.0, 6.0])
  })
  |> glint.execute(["--flag=5.0,6.0"])
  |> should.be_ok()
}

pub fn toggle_test() {
  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  glint.new()
  |> glint.add(
    [],
    glint.flag("flag", flag.bool(), fn(_) { glint.command(fn(_, _, _) { Nil }) }),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // boolean flag is toggled, sets value to True
  let flag_input = "--flag"

  glint.new()
  |> glint.add([], {
    use flag <- glint.flag("flag", flag.bool())
    use _, _, flags <- glint.command()
    flag(flags)
    |> should.equal(Ok(True))
  })
  |> glint.execute([flag_input])
  |> should.be_ok()

  // boolean flag with default of True is toggled, sets value to False
  let flag_input = "--flag"

  glint.new()
  |> glint.add([], {
    use flag <- glint.flag(
      "flag",
      flag.bool()
        |> flag.default(True),
    )
    use _, _, flags <- glint.command()
    flag(flags)
    |> should.equal(Ok(False))
  })
  |> glint.execute([flag_input])
  |> should.be_ok()

  // boolean flag without default toggled, sets value to True
  glint.new()
  |> glint.add([], {
    use flag <- glint.flag("flag", flag.bool())
    use _, _, flags <- glint.command()
    flag(flags)
    |> should.equal(Ok(True))
  })
  |> glint.execute([flag_input])
  |> should.be_ok()

  // cannot toggle non-bool flag
  glint.new()
  |> glint.add([], {
    use _flag <- glint.flag(
      "flag",
      flag.int()
        |> flag.default(1),
    )
    use _, _, _ <- glint.command()
    Nil
  })
  |> glint.execute([flag_input])
  |> should.be_error()
}

pub fn getters_test() {
  let flags =
    [
      #(
        "bflag",
        flag.build(
          flag.bool()
          |> flag.default(True),
        ),
      ),
      #(
        "sflag",
        flag.build(
          flag.string()
          |> flag.default(""),
        ),
      ),
      #(
        "lsflag",
        flag.build(
          flag.strings()
          |> flag.default([]),
        ),
      ),
      #(
        "iflag",
        flag.build(
          flag.int()
          |> flag.default(1),
        ),
      ),
      #(
        "liflag",
        flag.build(
          flag.ints()
          |> flag.default([]),
        ),
      ),
      #(
        "fflag",
        flag.build(
          flag.float()
          |> flag.default(1.0),
        ),
      ),
      #(
        "lfflag",
        flag.build(
          flag.floats()
          |> flag.default([]),
        ),
      ),
    ]
    |> list.fold(flag.flags(), fn(flags, t) { flag.insert(flags, t.0, t.1) })

  flag.get_bool(flags, "bflag")
  |> should.equal(Ok(True))

  flag.get_string(flags, "sflag")
  |> should.equal(Ok(""))

  flag.get_strings(flags, "lsflag")
  |> should.equal(Ok([]))

  flag.get_int(flags, "iflag")
  |> should.equal(Ok(1))

  flag.get_ints(flags, "liflag")
  |> should.equal(Ok([]))

  flag.get_float(flags, "fflag")
  |> should.equal(Ok(1.0))

  flag.get_floats(flags, "lfflag")
  |> should.equal(Ok([]))
}
