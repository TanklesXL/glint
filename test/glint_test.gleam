import birdie
import gleeunit
import gleeunit/should
import glint.{Help, Out}
import snag

pub fn main() {
  gleeunit.main()
}

pub fn path_clean_test() {
  glint.new()
  |> glint.add(["", " ", " cmd", "subcmd"], glint.command(fn(_, _, _) { Nil }))
  |> glint.execute(["cmd", "subcmd"])
  |> should.be_ok()
}

pub fn root_command_test() {
  // expecting no args
  glint.new()
  |> glint.add(
    at: [],
    do: glint.command(fn(_, args, _) { should.equal(args, []) }),
  )
  |> glint.execute([])
  |> should.be_ok()

  // expecting some args
  let args = ["arg1", "arg2"]
  let is_args = fn(_, in_args, _) { should.equal(in_args, args) }

  glint.new()
  |> glint.add(at: [], do: glint.command(is_args))
  |> glint.execute(args)
  |> should.be_ok()
}

pub fn command_routing_test() {
  let args = ["arg1", "arg2"]
  let is_args = fn(_, in_args, _) { should.equal(in_args, args) }
  let has_subcommand =
    glint.new()
    |> glint.add(["subcommand"], glint.command(is_args))

  // execute subommand with args
  has_subcommand
  |> glint.execute(["subcommand", ..args])
  |> should.be_ok()

  // no root command set, will return error
  has_subcommand
  |> glint.execute([])
  |> should.be_error()
}

pub fn nested_commands_test() {
  let args = ["arg1", "arg2"]
  let is_args = fn(_, in_args, _) { should.equal(in_args, args) }

  let cmd =
    glint.new()
    |> glint.add(["subcommand"], glint.command(is_args))
    |> glint.add(["subcommand", "subsubcommand"], glint.command(is_args))

  // call subcommand with args
  cmd
  |> glint.execute(["subcommand", ..args])
  |> should.be_ok()

  // call subcommand subsubcommand with args
  cmd
  |> glint.execute(["subcommand", "subsubcommand", ..args])
  |> should.be_ok()
}

pub fn runner_test() {
  let cmd =
    glint.new()
    |> glint.add(at: [], do: glint.command(fn(_, _, _) { Ok("success") }))
    |> glint.add(
      at: ["subcommand"],
      do: glint.command(fn(_, _, _) { snag.error("failed") }),
    )

  // command returns its own successful result
  cmd
  |> glint.execute([])
  |> should.equal(Ok(glint.Out(Ok("success"))))

  // command returns its own error result
  cmd
  |> glint.execute(["subcommand"])
  |> should.equal(Ok(Out(snag.error("failed"))))
}

pub fn help_test() {
  let nil = fn(_, _, _) { Nil }
  let global_flag =
    glint.string_flag("global")
    |> glint.flag_help("This is a global flag")

  let flag_1 =
    "flag1"
    |> glint.string_flag()
    |> glint.flag_help("This is flag1")

  let flag_2 =
    "flag2"
    |> glint.int_flag()
    |> glint.flag_help("This is flag2")
  let flag_3 =
    "flag3"
    |> glint.bool_flag()
    |> glint.flag_help("This is flag3")

  let flag_4 =
    "flag4"
    |> glint.float_flag()
    |> glint.flag_help("This is flag4")

  let flag_5 =
    "very-very-very-long-flag"
    |> glint.floats_flag()
    |> glint.flag_help(
      "This is a very long flag with a very very very very very very long description",
    )

  let cli =
    glint.new()
    |> glint.with_name("test")
    |> glint.global_help("Some awesome global help text!")
    |> glint.as_module
    |> glint.group_flag([], global_flag)
    |> glint.add(at: [], do: {
      use <- glint.command_help("This is the root command")
      use _arg1 <- glint.named_arg("arg1")
      use _arg2 <- glint.named_arg("arg2")
      use _flag <- glint.flag(flag_1)
      glint.command(nil)
    })
    |> glint.add(at: ["cmd1"], do: {
      use <- glint.command_help("This is cmd1")
      use _flag2 <- glint.flag(flag_2)
      use _flag5 <- glint.flag(flag_5)
      glint.command(nil)
    })
    |> glint.add(at: ["cmd1", "cmd3"], do: {
      use <- glint.command_help("This is cmd3")
      use _flag3 <- glint.flag(flag_3)
      use <- glint.unnamed_args(glint.MinArgs(2))
      use _woo <- glint.named_arg("woo")
      glint.command(nil)
    })
    |> glint.add(at: ["cmd1", "cmd4"], do: {
      use <- glint.command_help(
        "This is cmd4 which has a very very very very very very very very long description",
      )
      use _flag4 <- glint.flag(flag_4)
      use <- glint.unnamed_args(glint.EqArgs(0))
      glint.command(nil)
    })
    |> glint.add(at: ["cmd2"], do: {
      use <- glint.command_help("This is cmd2")
      use <- glint.unnamed_args(glint.EqArgs(0))
      use _arg1 <- glint.named_arg("arg1")
      use _arg2 <- glint.named_arg("arg2")
      glint.command(nil)
    })
    |> glint.add(
      at: ["cmd5", "cmd6"],
      do: glint.command_help("This is cmd6", fn() { glint.command(nil) }),
    )
    |> glint.path_help(["cmd5", "cmd6", "cmd7"], "This is cmd7")
    |> glint.path_help(
      ["cmd8-very-very-very-very-long"],
      "This is cmd8 with a very very very very very very very long description",
    )

  // execute root command
  glint.execute(cli, ["a", "b"])
  |> should.equal(Ok(Out(Nil)))

  glint.execute(cli, ["a"])
  |> should.be_error()

  glint.execute(cli, [])
  |> should.be_error()

  glint.execute(cli, ["cmd2"])
  |> should.be_error()

  glint.execute(cli, ["cmd2", "1"])
  |> should.be_error()

  glint.execute(cli, ["cmd2", "1", "2"])
  |> should.equal(Ok(Out(Nil)))

  glint.execute(cli, ["cmd2", "1", "2", "3"])
  |> should.be_error()

  let assert_unwrap_help = fn(res: Result(glint.Out(a), String)) -> String {
    let assert Ok(Help(help)) = res
    help
  }

  // help message for root command
  glint.execute(cli, ["--help"])
  |> assert_unwrap_help
  |> birdie.snap("root help")

  // help message for command
  glint.execute(cli, ["cmd1", "--help"])
  |> assert_unwrap_help
  |> birdie.snap("cmd1 help")

  // help message for nested command
  glint.execute(cli, ["cmd1", "cmd4", "--help"])
  |> assert_unwrap_help
  |> birdie.snap("cmd4 help")

  // help message for command with no additional flags
  glint.execute(cli, ["cmd2", "--help"])
  |> assert_unwrap_help
  |> birdie.snap("cmd2 help")

  // help message for command with no additional flags
  glint.execute(cli, ["cmd1", "cmd3", "--help"])
  |> assert_unwrap_help
  |> birdie.snap("cmd3 help")

  // help message for command a subcommand whose help was set with glint.path_help
  glint.execute(cli, ["cmd5", "cmd6", "--help"])
  |> assert_unwrap_help
  |> birdie.snap("cmd6 help")

  // help message for command that had help_text set with glint.glint.path_help
  // has no children or command runner set so no other details are available
  glint.execute(cli, ["cmd5", "cmd6", "cmd7", "--help"])
  |> assert_unwrap_help
  |> birdie.snap("cmd7 help")
}

pub fn global_and_group_flags_test() {
  let flag_f =
    glint.int_flag("f")
    |> glint.flag_default(2)
    |> glint.flag_help("global flag example")

  let sub_group_flag =
    "sub_group_flag"
    |> glint.int_flag()
    |> glint.flag_default(1)

  let cli =
    glint.new()
    |> glint.group_flag([], flag_f)
    |> glint.add(
      [],
      glint.command(fn(_, _, flags) {
        glint.get_flag(flags, flag_f)
        |> should.equal(Ok(2))
      }),
    )
    |> glint.add(["sub"], {
      use f <- glint.flag(
        "f"
        |> glint.bool_flag()
        |> glint.flag_default(True)
        |> glint.flag_help("i decided to override the global flag"),
      )
      use _, _, flags <- glint.command()
      f(flags)
      |> should.equal(Ok(True))
    })
    |> glint.group_flag(["sub"], sub_group_flag)
    |> glint.add(["sub", "sub"], {
      use f <- glint.flag(
        "f"
        |> glint.bool_flag()
        |> glint.flag_default(True)
        |> glint.flag_help("i decided to override the global flag"),
      )
      use _, _, flags <- glint.command()
      f(flags)
      |> should.equal(Ok(True))

      flags
      |> glint.get_flag(sub_group_flag)
      |> should.equal(Ok(2))
    })

  // root command keeps the global flag as an int
  cli
  |> glint.execute(["--f=2"])
  |> should.be_ok

  cli
  |> glint.execute(["--f=hello"])
  |> should.be_error

  // sub command overrides the global flag with a bool
  cli
  |> glint.execute(["sub", "--f=true"])
  |> should.be_ok

  cli
  |> glint.execute(["sub", "--f=123"])
  |> should.be_error

  cli
  |> glint.execute(["sub", "sub", "--sub_group_flag=2"])
}

pub fn default_pretty_help_test() {
  // default_pretty_help has asserts
  // we need to call the function to make sure it does not crash
  glint.default_pretty_help()
}
