import glint
import glint/constraint

pub fn one_of_test() {
  assert constraint.one_of([1, 2, 3])(1) == Ok(1)

  let assert Error(_) = constraint.one_of([2, 3, 4])(1)

  assert {
      [5, 4, 3, 2, 1]
      |> constraint.one_of
      |> constraint.each
    }([1, 2, 3])
    == Ok([1, 2, 3])

  let assert Error(_) =
    {
      [5, 4, 3, 2, 1]
      |> constraint.one_of
      |> constraint.each
    }([1, 6, 3])
}

pub fn none_of_test() {
  let assert Error(_) = constraint.none_of([1, 2, 3])(1)

  assert constraint.none_of([2, 3, 4])(1) == Ok(1)

  assert {
      [4, 5, 6, 7, 8]
      |> constraint.none_of
      |> constraint.each
    }([1, 2, 3])
    == Ok([1, 2, 3])

  let assert Error(_) =
    {
      [4, 5, 6, 7, 8]
      |> constraint.none_of
      |> constraint.each
    }([1, 6, 3])
}

pub fn flag_one_of_none_of_test() {
  let #(test_flag, success, failure) = #(
    glint.int("i")
      |> glint.constraint(constraint.one_of([1, 2, 3]))
      |> glint.constraint(constraint.none_of([4, 5, 6])),
    "1",
    "6",
  )

  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use access <- glint.flag(test_flag)
      use _, _, flags <- glint.command()
      let assert Ok(_) = access(flags)
    })
    |> glint.run(["--i=" <> success])

  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _access <- glint.flag(test_flag)
      use _, _, _flags <- glint.command()
      Nil
    })
    |> glint.run(["--i=" <> failure])

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

  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use access <- glint.flag(test_flag)
      use _, _, flags <- glint.command()
      let assert Ok(_) = access(flags)
    })
    |> glint.run(["--li=" <> success])

  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _access <- glint.flag(test_flag)
      use _, _, _flags <- glint.command()
      panic
    })
    |> glint.run(["--li=" <> failure])

  let #(test_flag, success, failure) = #(
    glint.float("f")
      |> glint.constraint(constraint.one_of([1.0, 2.0, 3.0]))
      |> glint.constraint(constraint.none_of([4.0, 5.0, 6.0])),
    "1.0",
    "6.0",
  )
  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use access <- glint.flag(test_flag)
      use _, _, flags <- glint.command()
      let assert Ok(_) = access(flags)
    })
    |> glint.run(["--f=" <> success])

  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _access <- glint.flag(test_flag)
      use _, _, _flags <- glint.command()
      panic
    })
    |> glint.run(["--f=" <> failure])

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
  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use access <- glint.flag(test_flag)
      use _, _, flags <- glint.command()
      let assert Ok(_) = access(flags)
    })
    |> glint.run(["--lf=" <> success])

  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _access <- glint.flag(test_flag)
      use _, _, _flags <- glint.command()
      panic
    })
    |> glint.run(["--lf=" <> failure])

  let #(test_flag, success, failure) = #(
    glint.string("s")
      |> glint.constraint(constraint.one_of(["t1", "t2", "t3"]))
      |> glint.constraint(constraint.none_of(["t4", "t5", "t6"])),
    "t3",
    "t4",
  )

  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use access <- glint.flag(test_flag)
      use _, _, flags <- glint.command()
      let assert Ok(_) = access(flags)
    })
    |> glint.run(["--s=" <> success])

  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _access <- glint.flag(test_flag)
      use _, _, _flags <- glint.command()
      panic
    })
    |> glint.run(["--s=" <> failure])

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

  let assert Ok(_) =
    glint.new()
    |> glint.add([], {
      use access <- glint.flag(test_flag)
      use _, _, flags <- glint.command()
      let assert Ok(_) = access(flags)
    })
    |> glint.run(["--ls=" <> success])

  let assert Error(_) =
    glint.new()
    |> glint.add([], {
      use _access <- glint.flag(test_flag)
      use _, _, _flags <- glint.command()
      panic
    })
    |> glint.run(["--ls=" <> failure])
}
