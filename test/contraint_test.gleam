import gleeunit/should
import glint
import glint/constraint

pub fn one_of_test() {
  1
  |> constraint.one_of([1, 2, 3])
  |> should.equal(Ok(1))

  1
  |> constraint.one_of([2, 3, 4])
  |> should.be_error()

  [1, 2, 3]
  |> {
    [5, 4, 3, 2, 1]
    |> constraint.one_of
    |> constraint.each
  }
  |> should.equal(Ok([1, 2, 3]))

  [1, 6, 3]
  |> {
    [5, 4, 3, 2, 1]
    |> constraint.one_of
    |> constraint.each
  }
  |> should.be_error()
}

pub fn none_of_test() {
  1
  |> constraint.none_of([1, 2, 3])
  |> should.be_error

  1
  |> constraint.none_of([2, 3, 4])
  |> should.equal(Ok(1))

  [1, 2, 3]
  |> {
    [4, 5, 6, 7, 8]
    |> constraint.none_of
    |> constraint.each
  }
  |> should.equal(Ok([1, 2, 3]))

  [1, 6, 3]
  |> {
    [4, 5, 6, 7, 8]
    |> constraint.none_of
    |> constraint.each
  }
  |> should.be_error()
}

pub fn flag_one_of_none_of_test() {
  let #(test_flag, success, failure) = #(
    glint.int("i")
      |> glint.constraint(constraint.one_of([1, 2, 3]))
      |> glint.constraint(constraint.none_of([4, 5, 6])),
    "1",
    "6",
  )

  glint.new()
  |> glint.add([], {
    use access <- glint.flag(test_flag)
    use _, _, flags <- glint.command()
    flags
    |> access
    |> should.be_ok
  })
  |> glint.execute(["--i=" <> success])
  |> should.be_ok

  glint.new()
  |> glint.add([], {
    use _access <- glint.flag(test_flag)
    use _, _, _flags <- glint.command()
    Nil
  })
  |> glint.execute(["--i=" <> failure])
  |> should.be_error

  let #(test_flag, success, failure) = #(
    glint.ints("li")
      |> glint.constraint(
        [1, 2, 3]
        |> constraint.one_of
        |> constraint.each,
      )
      |> glint.constraint(
        [4, 5, 6]
        |> constraint.none_of
        |> constraint.each,
      ),
    "1,1,1",
    "2,2,6",
  )

  glint.new()
  |> glint.add([], {
    use access <- glint.flag(test_flag)
    use _, _, flags <- glint.command()
    flags
    |> access
    |> should.be_ok
  })
  |> glint.execute(["--li=" <> success])
  |> should.be_ok

  glint.new()
  |> glint.add([], {
    use _access <- glint.flag(test_flag)
    use _, _, _flags <- glint.command()
    panic
  })
  |> glint.execute(["--li=" <> failure])
  |> should.be_error

  let #(test_flag, success, failure) = #(
    glint.float("f")
      |> glint.constraint(constraint.one_of([1.0, 2.0, 3.0]))
      |> glint.constraint(constraint.none_of([4.0, 5.0, 6.0])),
    "1.0",
    "6.0",
  )
  glint.new()
  |> glint.add([], {
    use access <- glint.flag(test_flag)
    use _, _, flags <- glint.command()
    flags
    |> access
    |> should.be_ok
  })
  |> glint.execute(["--f=" <> success])
  |> should.be_ok

  glint.new()
  |> glint.add([], {
    use _access <- glint.flag(test_flag)
    use _, _, _flags <- glint.command()
    panic
  })
  |> glint.execute(["--f=" <> failure])
  |> should.be_error

  let #(test_flag, success, failure) = #(
    glint.floats("lf")
      |> glint.constraint(
        [1.0, 2.0, 3.0]
        |> constraint.one_of()
        |> constraint.each,
      )
      |> glint.constraint(
        [4.0, 5.0, 6.0]
        |> constraint.none_of()
        |> constraint.each,
      ),
    "3.0,2.0,1.0",
    "2.0,3.0,6.0",
  )
  glint.new()
  |> glint.add([], {
    use access <- glint.flag(test_flag)
    use _, _, flags <- glint.command()
    flags
    |> access
    |> should.be_ok
  })
  |> glint.execute(["--lf=" <> success])
  |> should.be_ok

  glint.new()
  |> glint.add([], {
    use _access <- glint.flag(test_flag)
    use _, _, _flags <- glint.command()
    panic
  })
  |> glint.execute(["--lf=" <> failure])
  |> should.be_error

  let #(test_flag, success, failure) = #(
    glint.string("s")
      |> glint.constraint(constraint.one_of(["t1", "t2", "t3"]))
      |> glint.constraint(constraint.none_of(["t4", "t5", "t6"])),
    "t3",
    "t4",
  )

  glint.new()
  |> glint.add([], {
    use access <- glint.flag(test_flag)
    use _, _, flags <- glint.command()
    flags
    |> access
    |> should.be_ok
  })
  |> glint.execute(["--s=" <> success])
  |> should.be_ok

  glint.new()
  |> glint.add([], {
    use _access <- glint.flag(test_flag)
    use _, _, _flags <- glint.command()
    panic
  })
  |> glint.execute(["--s=" <> failure])
  |> should.be_error

  let #(test_flag, success, failure) = #(
    glint.strings("ls")
      |> glint.constraint(
        ["t1", "t2", "t3"]
        |> constraint.one_of
        |> constraint.each,
      )
      |> glint.constraint(
        ["t4", "t5", "t6"]
        |> constraint.none_of
        |> constraint.each,
      ),
    "t3,t2,t1",
    "t2,t4,t1",
  )

  glint.new()
  |> glint.add([], {
    use access <- glint.flag(test_flag)
    use _, _, flags <- glint.command()
    flags
    |> access
    |> should.be_ok
  })
  |> glint.execute(["--ls=" <> success])
  |> should.be_ok

  glint.new()
  |> glint.add([], {
    use _access <- glint.flag(test_flag)
    use _, _, _flags <- glint.command()
    panic
  })
  |> glint.execute(["--ls=" <> failure])
  |> should.be_error
}
