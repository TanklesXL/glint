import gleeunit
import gleeunit/should
import glint.{Help, Out}
import snag

pub fn main() {
  gleeunit.main()
}

pub fn path_clean_test() {
  glint.new()
  |> glint.add(
    ["", " ", " cmd", "subcmd\t"],
    glint.command(fn(_, _, _) { Nil }),
  )
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
    glint.string("global")
    |> glint.flag_help("This is a global flag")

  let flag_1 =
    "flag1"
    |> glint.string()
    |> glint.flag_help("This is flag1")

  let flag_2 =
    "flag2"
    |> glint.int()
    |> glint.flag_help("This is flag2")
  let flag_3 =
    "flag3"
    |> glint.bool()
    |> glint.flag_help("This is flag3")

  let flag_4 =
    "flag4"
    |> glint.float()
    |> glint.flag_help("This is flag4")

  let flag_5 =
    "flag5"
    |> glint.floats()
    |> glint.flag_help("This is flag5")

  let cli =
    glint.new()
    |> glint.with_name("test")
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
      use <- glint.command_help("This is cmd4")
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

  // help message for root command
  glint.execute(cli, ["--help"])
  |> should.equal(
    Ok(Help(
      "This is the root command

USAGE:
\tgleam run -m test ( cmd1 | cmd2 | cmd5 ) <arg1> <arg2> [ ARGS ] [ --flag1=<STRING> --global=<STRING> ]

FLAGS:
\t--flag1=<STRING>\t\tThis is flag1
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information

SUBCOMMANDS:
\tcmd1\t\tThis is cmd1
\tcmd2\t\tThis is cmd2
\tcmd5",
    )),
  )

  // help message for command
  glint.execute(cli, ["cmd1", "--help"])
  |> should.equal(
    Ok(Help(
      "cmd1
This is cmd1

USAGE:
\tgleam run -m test cmd1 ( cmd3 | cmd4 ) [ ARGS ] [ --flag2=<INT> --flag5=<FLOAT_LIST> --global=<STRING> ]

FLAGS:
\t--flag2=<INT>\t\tThis is flag2
\t--flag5=<FLOAT_LIST>\t\tThis is flag5
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information

SUBCOMMANDS:
\tcmd3\t\tThis is cmd3
\tcmd4\t\tThis is cmd4",
    )),
  )

  // help message for nested command
  glint.execute(cli, ["cmd1", "cmd4", "--help"])
  |> should.equal(
    Ok(Help(
      "cmd1 cmd4
This is cmd4

USAGE:
\tgleam run -m test cmd1 cmd4 [ --flag4=<FLOAT> --global=<STRING> ]

FLAGS:
\t--flag4=<FLOAT>\t\tThis is flag4
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information",
    )),
  )
  // help message for command with no additional flags
  glint.execute(cli, ["cmd2", "--help"])
  |> should.equal(
    Ok(Help(
      "cmd2
This is cmd2

USAGE:
\tgleam run -m test cmd2 <arg1> <arg2> [ --global=<STRING> ]

FLAGS:
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information",
    )),
  )

  // help message for command with no additional flags
  glint.execute(cli, ["cmd1", "cmd3", "--help"])
  |> should.equal(
    Ok(Help(
      "cmd1 cmd3
This is cmd3

USAGE:
\tgleam run -m test cmd1 cmd3 <woo> [ 2 or more arguments ] [ --flag3=<BOOL> --global=<STRING> ]

FLAGS:
\t--flag3=<BOOL>\t\tThis is flag3
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information",
    )),
  )

  // help message for command a subcommand whose help was set with glint.path_help
  glint.execute(cli, ["cmd5", "cmd6", "--help"])
  |> should.equal(
    Ok(Help(
      "cmd5 cmd6
This is cmd6

USAGE:
\tgleam run -m test cmd5 cmd6 ( cmd7 ) [ ARGS ] [ --global=<STRING> ]

FLAGS:
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information

SUBCOMMANDS:
\tcmd7\t\tThis is cmd7",
    )),
  )

  // help message for command that had help_text set with glint.glint.path_help
  // has no children or command runner set so no other details are available
  glint.execute(cli, ["cmd5", "cmd6", "cmd7", "--help"])
  |> should.equal(
    Ok(Help(
      "cmd5 cmd6 cmd7
This is cmd7

USAGE:
\tgleam run -m test cmd5 cmd6 cmd7 [ ARGS ]",
    )),
  )
}

pub fn global_and_group_flags_test() {
  let flag_f =
    glint.int("f")
    |> glint.flag_default(2)
    |> glint.flag_help("global flag example")

  let sub_group_flag =
    "sub_group_flag"
    |> glint.int()
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
        |> glint.bool()
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
        |> glint.bool()
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
