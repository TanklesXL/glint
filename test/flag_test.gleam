import gleeunit/should
import glint

pub fn update_flag_test() {
  let app =
    glint.new()
    |> glint.add([], {
      use _bflag <- glint.flag("bflag", glint.bool())
      use _sflag <- glint.flag("sflag", glint.string())
      use _lsflag <- glint.flag("lsflag", glint.strings())
      use _iflag <- glint.flag("iflag", glint.int())
      use _liflag <- glint.flag("liflag", glint.ints())
      use _fflag <- glint.flag("fflag", glint.float())
      use _lfflag <- glint.flag("lfflag", glint.floats())
      glint.command(fn(_, _, _) { Nil })
    })

  // update non-existent flag fails
  app
  |> glint.execute(["--not_a_flag=hello"])
  |> should.be_error()

  // update bool flag succeeds
  app
  |> glint.execute(["--bflag=true"])
  |> should.be_ok()

  // update bool flag with non-bool value fails
  app
  |> glint.execute(["--bflag=zzz"])
  |> should.be_error()

  // toggle bool flag succeeds
  app
  |> glint.execute(["--bflag"])
  |> should.be_ok()

  // toggle non-bool flag succeeds
  app
  |> glint.execute(["--sflag"])
  |> should.be_error()

  // update string flag succeeds
  app
  |> glint.execute(["--sflag=hello"])
  |> should.be_ok()

  // update int flag with non-int fails
  app
  |> glint.execute(["--iflag=hello"])
  |> should.be_error()

  // update int flag with int succeeds
  app
  |> glint.execute(["--iflag=1"])
  |> should.be_ok()

  // update int list flag with int list succeeds
  app
  |> glint.execute(["--liflag=1,2,3"])
  |> should.be_ok()

  // update int list flag with non int list succeeds
  app
  |> glint.execute(["--liflag=a,b,c"])
  |> should.be_error()

  // update float flag with non-int fails
  app
  |> glint.execute(["--fflag=hello"])
  |> should.be_error()

  // update float flag with int succeeds
  app
  |> glint.execute(["--fflag=1.0"])
  |> should.be_ok()

  // update float list flag with int list succeeds
  app
  |> glint.execute(["--lfflag=1.0,2.0,3.0"])
  |> should.be_ok()

  // update float list flag with non int list succeeds
  app
  |> glint.execute(["--lfflag=a,b,c"])
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
    glint.string()
      |> glint.default("default"),
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
  let flag = #("flag", glint.string())
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
  let flags = #("flag", glint.int())

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
  let flag = #("flag", glint.bool())

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
  let flags = #("flag", glint.strings())
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
  let flag = #("flag", glint.ints())

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
  let flag = #("flag", glint.float())

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
  let flag = #("flag", glint.floats())

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
    |> glint.get_floats("flag")
    |> should.equal(Ok(vals))
  }

  // set global flag, pass in  new value for flag
  glint.new()
  |> glint.group_flag([], "flag", glint.floats())
  |> glint.add(at: [], do: testcase([3.0, 4.0]))
  |> glint.execute(["--flag=3.0,4.0"])
  |> should.be_ok()

  // set global flag and local flag, local flag should take priority
  glint.new()
  |> glint.group_flag([], "flag", glint.floats())
  |> glint.add(
    at: [],
    do: glint.flag(
      "flag",
      glint.floats()
        |> glint.default([1.0, 2.0]),
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
    glint.floats()
      |> glint.default([3.0, 4.0]),
  )
  |> glint.add(at: [], do: {
    use _flag <- glint.flag(
      "flag",
      glint.floats()
        |> glint.default([1.0, 2.0]),
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
    glint.flag("flag", glint.bool(), fn(_) {
      glint.command(fn(_, _, _) { Nil })
    }),
  )
  |> glint.execute([flag_input])
  |> should.be_error()

  // boolean flag is toggled, sets value to True
  let flag_input = "--flag"

  glint.new()
  |> glint.add([], {
    use flag <- glint.flag("flag", glint.bool())
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
      glint.bool()
        |> glint.default(True),
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
    use flag <- glint.flag("flag", glint.bool())
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
      glint.int()
        |> glint.default(1),
    )
    use _, _, _ <- glint.command()
    Nil
  })
  |> glint.execute([flag_input])
  |> should.be_error()
}

pub fn getters_test() {
  glint.new()
  |> glint.add([], {
    use bflag <- glint.flag(
      "bflag",
      glint.bool()
        |> glint.default(True),
    )
    use sflag <- glint.flag(
      "sflag",
      glint.string()
        |> glint.default(""),
    )
    use lsflag <- glint.flag(
      "lsflag",
      glint.strings()
        |> glint.default([]),
    )
    use iflag <- glint.flag(
      "iflag",
      glint.int()
        |> glint.default(1),
    )
    use liflag <- glint.flag(
      "liflag",
      glint.ints()
        |> glint.default([]),
    )
    use fflag <- glint.flag(
      "fflag",
      glint.float()
        |> glint.default(1.0),
    )
    use lfflag <- glint.flag(
      "lfflag",
      glint.floats()
        |> glint.default([]),
    )

    use _, _, flags <- glint.command()
    bflag(flags)
    |> should.equal(Ok(True))

    sflag(flags)
    |> should.equal(Ok(""))

    lsflag(flags)
    |> should.equal(Ok([]))

    iflag(flags)
    |> should.equal(Ok(1))

    liflag(flags)
    |> should.equal(Ok([]))

    fflag(flags)
    |> should.equal(Ok(1.0))

    lfflag(flags)
    |> should.equal(Ok([]))
  })
  |> glint.execute([])
}
