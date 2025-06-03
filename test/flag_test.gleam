import glint

pub fn update_flag_test() {
  let app =
    glint.new()
    |> glint.add([], {
      use _bflag <- glint.flag(glint.bool("bflag"))
      use _sflag <- glint.flag(glint.string("sflag"))
      use _lsflag <- glint.flag(glint.strings("lsflag"))
      use _iflag <- glint.flag(glint.ints("iflag"))
      use _liflag <- glint.flag(glint.ints("liflag"))
      use _fflag <- glint.flag(glint.float("fflag"))
      use _lfflag <- glint.flag(glint.floats("lfflag"))
      glint.command(fn(_, _, _) { Nil })
    })

  // update non-existent flag fails
  let assert Error(_) = glint.run(app, ["--not_a_flag=hello"])

  // update bool flag succeeds
  let assert Ok(_) = glint.run(app, ["--bflag=true"])

  // update bool flag with non-bool value fails
  let assert Error(_) = glint.run(app, ["--bflag=zzz"])

  // toggle bool flag succeeds
  let assert Ok(_) = glint.run(app, ["--bflag"])

  // toggle non-bool flag succeeds
  let assert Error(_) = glint.run(app, ["--sflag"])

  // update string flag succeeds
  let assert Ok(_) = glint.run(app, ["--sflag=hello"])

  // update int flag with non-int fails
  let assert Error(_) = glint.run(app, ["--iflag=hello"])

  // update int flag with int succeeds
  let assert Ok(_) = glint.run(app, ["--iflag=1"])

  // update int list flag with int list succeeds
  let assert Ok(_) = glint.run(app, ["--liflag=1,2,3"])

  // update int list flag with non int list succeeds
  let assert Error(_) = glint.run(app, ["--liflag=a,b,c"])

  // update float flag with non-int fails
  let assert Error(_) = glint.run(app, ["--fflag=hello"])

  // update float flag with int succeeds
  let assert Ok(_) = glint.run(app, ["--fflag=1.0"])

  // update float list flag with int list succeeds
  let assert Ok(_) = glint.run(app, ["--lfflag=1.0,2.0,3.0"])

  // update float list flag with non int list succeeds
  let assert Error(_) = glint.run(app, ["--lfflag=a,b,c"])
}

pub fn unsupported_flag_test() {
  let assert Error(_) =
    glint.new()
    |> glint.add(["cmd"], glint.command(fn(_, _, _) { Nil }))
    |> glint.run(["--flag=1"])
}

pub fn flag_default_test() {
  let args = ["arg1", "arg2"]
  let flag =
    glint.string("flag")
    |> glint.default("default")

  let assert Ok(_) =
    glint.new()
    |> glint.add(["cmd"], {
      use flag_ <- glint.flag(flag)
      use _, unnamed, flags <- glint.command()
      assert args == unnamed
      assert flag_(flags) == Ok("default")
    })
    |> glint.run(["cmd", ..args])
}

pub fn flag_value_test() {
  let args = ["arg1", "arg2"]
  let flag = glint.string("flag")
  let flag_input = "--flag=flag_value"
  let flag_value_should_be_set = {
    use flag_ <- glint.flag(flag)
    use _, in_args, flags <- glint.command()
    assert in_args == args

    assert flag_(flags) == Ok("flag_value")
  }

  let assert Ok(_) =
    glint.new()
    |> glint.add(["cmd"], flag_value_should_be_set)
    |> glint.run(["cmd", flag_input, ..args])
}

pub fn int_flag_test() {
  let flags = glint.int("flag")
  // fails to parse input for flag as int, returns error
  let flag_input = "--flag=X"
  let assert Error(_) =
    glint.new()
    |> glint.add(
      [],
      glint.flag(flags, fn(_flag) { glint.command(fn(_, _, _) { Nil }) }),
    )
    |> glint.run([flag_input])

  // parses flag input as int, sets value
  let flag_input = "--flag=10"
  let expect_flag_value_of_10 = {
    use flag_ <- glint.flag(flags)
    use _, _, flags <- glint.command()
    assert flag_(flags) == Ok(10)
  }

  let assert Ok(_) =
    glint.new()
    |> glint.add([], expect_flag_value_of_10)
    |> glint.run([flag_input])
}

pub fn bool_flag_test() {
  let flag = glint.bool("flag")

  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  let assert Error(_) =
    glint.new()
    |> glint.add(
      [],
      glint.flag(flag, fn(_flag) { glint.command(fn(_, _, _) { Nil }) }),
    )
    |> glint.run([flag_input])

  // parses flag input as bool, sets value
  let flag_input = "--flag=false"
  let expect_flag_value_of_false = fn(flag) {
    glint.command(fn(_, _, flags) {
      assert flag(flags) == Ok(False)
    })
  }

  let assert Ok(_) =
    glint.new()
    |> glint.add([], glint.flag(flag, expect_flag_value_of_false))
    |> glint.run([flag_input])
}

pub fn strings_flag_test() {
  let flags = glint.strings("flag")
  let flag_input = "--flag=val3,val4"
  let expect_flag_value_list = fn(flag) {
    glint.command(fn(_, _, flags) {
      assert flag(flags) == Ok(["val3", "val4"])
    })
  }

  let assert Ok(_) =
    glint.new()
    |> glint.add([], glint.flag(flags, expect_flag_value_list))
    |> glint.run([flag_input])
}

pub fn ints_flag_test() {
  let flag = glint.ints("flag")

  // fails to parse input for flag as int list, returns error
  let flag_input = "--flag=val3,val4"
  let assert Error(_) =
    glint.new()
    |> glint.add(
      [],
      glint.flag(flag, fn(_) { glint.command(fn(_, _, _) { Nil }) }),
    )
    |> glint.run([flag_input])

  // parses flag input as int list, sets value
  let flag_input = "--flag=3,4"
  let expect_flag_value_list = fn(flag) {
    glint.command(fn(_, _, flags) {
      assert flag(flags) == Ok([3, 4])
    })
  }

  let assert Ok(_) =
    glint.new()
    |> glint.add([], glint.flag(flag, expect_flag_value_list))
    |> glint.run([flag_input])
}

pub fn float_flag_test() {
  let flag = glint.float("flag")

  // fails to parse input for flag as float, returns error
  let flag_input = "--flag=X"
  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _flag <- glint.flag(flag)
      use _, _, _ <- glint.command()
      Nil
    })
    |> glint.run([flag_input])

  // parses flag input as float, sets value
  let flag_input = "--flag=10.0"
  let expect_flag_value_of_10 = {
    use flag <- glint.flag(flag)
    use _, _, flags <- glint.command()
    assert flag(flags) == Ok(10.0)
  }

  let assert Ok(_) =
    glint.new()
    |> glint.add([], expect_flag_value_of_10)
    |> glint.run([flag_input])
}

pub fn floats_flag_test() {
  let flag = glint.floats("flag")

  // fails to parse input for flag as float list, returns error
  let flag_input = "--flag=val3,val4"
  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _flag <- glint.flag(flag)
      use _, _, _ <- glint.command()
      Nil
    })
    |> glint.run([flag_input])

  // parses flag input as float list, sets value
  let flag_input = "--flag=3.0,4.0"
  let expect_flag_value_list = {
    use flag <- glint.flag(flag)
    use _, _, flags <- glint.command
    assert flag(flags) == Ok([3.0, 4.0])
  }
  let assert Ok(_) =
    glint.new()
    |> glint.add([], expect_flag_value_list)
    |> glint.run([flag_input])
}

pub fn global_flag_test() {
  let flag = glint.floats("flag")
  let testcase = fn(vals: List(Float)) {
    use _, _, flags <- glint.command()
    assert glint.get_flag(flags, flag) == Ok(vals)
  }

  // set global flag, pass in  new value for flag
  let assert Ok(_) =
    glint.new()
    |> glint.group_flag([], flag)
    |> glint.add(at: [], do: testcase([3.0, 4.0]))
    |> glint.run(["--flag=3.0,4.0"])

  // set global flag and local flag, local flag should take priority
  let assert Ok(_) =
    glint.new()
    |> glint.group_flag([], glint.floats("flag"))
    |> glint.add(
      at: [],
      do: glint.flag(
        glint.floats("flag")
          |> glint.default([1.0, 2.0]),
        fn(_) { testcase([1.0, 2.0]) },
      ),
    )
    |> glint.run([])

  // set global flag and local flag, pass in new value for flag
  let assert Ok(_) =
    glint.new()
    |> glint.group_flag(
      [],
      glint.floats("flag")
        |> glint.default([3.0, 4.0]),
    )
    |> glint.add(at: [], do: {
      use _flag <- glint.flag(
        glint.floats("flag")
        |> glint.default([1.0, 2.0]),
      )

      testcase([5.0, 6.0])
    })
    |> glint.run(["--flag=5.0,6.0"])
}

pub fn toggle_test() {
  // fails to parse input for flag as bool, returns error
  let flag_input = "--flag=X"
  let assert Error(_) =
    glint.new()
    |> glint.add(
      [],
      glint.flag(glint.bool("flag"), fn(_) {
        glint.command(fn(_, _, _) { Nil })
      }),
    )
    |> glint.run([flag_input])

  // boolean flag is toggled, sets value to True
  let flag_input = "--flag"

  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use flag <- glint.flag(glint.bool("flag"))
      use _, _, flags <- glint.command()
      assert flag(flags) == Ok(True)
    })
    |> glint.run([flag_input])

  // boolean flag with default of True is toggled, sets value to False
  let flag_input = "--flag"

  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use flag <- glint.flag(
        glint.bool("flag")
        |> glint.default(True),
      )
      use _, _, flags <- glint.command()
      assert flag(flags) == Ok(False)
    })
    |> glint.run([flag_input])

  // boolean flag without default toggled, sets value to True
  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use flag <- glint.flag(glint.bool("flag"))
      use _, _, flags <- glint.command()
      assert flag(flags) == Ok(True)
    })
    |> glint.run([flag_input])

  // cannot toggle non-bool flag
  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _flag <- glint.flag(
        glint.int("flag")
        |> glint.default(1),
      )
      use _, _, _ <- glint.command()
      Nil
    })
    |> glint.run([flag_input])
}

pub fn getters_test() {
  glint.new()
  |> glint.add([], {
    use bflag <- glint.flag(
      glint.bool("bflag")
      |> glint.default(True),
    )
    use sflag <- glint.flag(
      glint.string("sflag")
      |> glint.default(""),
    )
    use lsflag <- glint.flag(
      glint.strings("lsflag")
      |> glint.default([]),
    )
    use iflag <- glint.flag(
      glint.int("iflag")
      |> glint.default(1),
    )
    use liflag <- glint.flag(
      glint.ints("liflag")
      |> glint.default([]),
    )
    use fflag <- glint.flag(
      glint.float("fflag")
      |> glint.default(1.0),
    )
    use lfflag <- glint.flag(
      glint.floats("lfflag")
      |> glint.default([]),
    )

    use _, _, flags <- glint.command()
    assert bflag(flags) == Ok(True)

    assert sflag(flags) == Ok("")

    assert lsflag(flags) == Ok([])

    assert iflag(flags) == Ok(1)

    assert liflag(flags) == Ok([])

    assert fflag(flags) == Ok(1.0)

    assert lfflag(flags) == Ok([])
  })
  |> glint.run([])
}
