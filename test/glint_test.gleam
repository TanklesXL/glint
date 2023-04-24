import gleeunit
import gleeunit/should
import glint.{CommandInput, Help, Out}
import glint/flag
import gleam/function
import snag

pub fn main() {
  gleeunit.main()
}

pub fn path_clean_test() {
  glint.new()
  |> glint.add(["", " ", " cmd", "subcmd\t"], glint.cmd(fn(_) { Nil }))
  |> glint.execute(["cmd", "subcmd"])
  |> should.be_ok()
}

pub fn root_command_test() {
  // expecting no args
  glint.new()
  |> glint.add(
    at: [],
    do: glint.cmd(fn(in: CommandInput) { should.equal(in.args, []) }),
  )
  |> glint.execute([])
  |> should.be_ok()

  // expecting some args
  let args = ["arg1", "arg2"]
  let is_args = fn(in: CommandInput) { should.equal(in.args, args) }

  glint.new()
  |> glint.add(at: [], do: glint.cmd(is_args))
  |> glint.execute(args)
  |> should.be_ok()
}

pub fn command_routing_test() {
  let args = ["arg1", "arg2"]
  let is_args = fn(in: CommandInput) { should.equal(in.args, args) }

  let has_subcommand =
    glint.new()
    |> glint.add(["subcommand"], glint.cmd(is_args))

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
  let is_args = fn(in: CommandInput) { should.equal(in.args, args) }

  let cmd =
    glint.new()
    |> glint.add(["subcommand"], glint.cmd(is_args))
    |> glint.add(["subcommand", "subsubcommand"], glint.cmd(is_args))

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
    |> glint.add(at: [], do: glint.cmd(fn(_) { Ok("success") }))
    |> glint.add(
      at: ["subcommand"],
      do: glint.cmd(fn(_) { snag.error("failed") }),
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
  let nil = function.constant(Nil)
  let global_flags = [
    #(
      "global",
      flag.new(flag.S)
      |> flag.desc("This is a global flag"),
    ),
  ]
  let flag_1 = #(
    "flag1",
    flag.new(flag.S)
    |> flag.desc("This is flag1"),
  )
  let flag_2 = #(
    "flag2",
    flag.new(flag.I)
    |> flag.desc("This is flag2"),
  )
  let flag_3 = #(
    "flag3",
    flag.new(flag.B)
    |> flag.desc("This is flag3"),
  )
  let flag_4 = #(
    "flag4",
    flag.new(flag.F)
    |> flag.desc("This is flag4"),
  )
  let flag_5 = #(
    "flag5",
    flag.new(flag.LF)
    |> flag.desc("This is flag5"),
  )

  let cli =
    glint.new()
    |> glint.with_global_flags(global_flags)
    |> glint.add(
      at: [],
      do: glint.cmd(do: nil)
      |> glint.flag(flag_1.0, flag_1.1)
      |> glint.desc("This is the root command"),
    )
    |> glint.add(
      at: ["cmd1"],
      do: glint.cmd(nil)
      |> glint.flags([flag_2, flag_5])
      |> glint.desc("This is cmd1"),
    )
    |> glint.add(
      at: ["cmd1", "cmd3"],
      do: glint.cmd(nil)
      |> glint.flag(flag_3.0, flag_3.1)
      |> glint.desc("This is cmd3"),
    )
    |> glint.add(
      at: ["cmd1", "cmd4"],
      do: glint.cmd(nil)
      |> glint.flag(flag_4.0, flag_4.1)
      |> glint.desc("This is cmd4"),
    )
    |> glint.add(
      at: ["cmd2"],
      do: glint.cmd(nil)
      |> glint.desc("This is cmd2"),
    )
    |> glint.add(
      at: ["cmd5", "cmd6"],
      do: glint.cmd(nil)
      |> glint.desc("This is cmd6"),
    )

  // execute root command
  glint.execute(cli, [])
  |> should.equal(Ok(Out(Nil)))

  // help message for root command
  glint.execute(cli, [glint.help_flag()])
  |> should.equal(Ok(Help(
    "This is the root command

USAGE:
\tgleam run [ ARGS ] [ --flag1=<STRING> --global=<STRING> ]

FLAGS:
\t--flag1=<STRING>\t\tThis is flag1
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information

SUBCOMMANDS:
\tcmd1\t\tThis is cmd1
\tcmd2\t\tThis is cmd2
\tcmd5",
  )))

  // help message for command
  glint.execute(cli, ["cmd1", glint.help_flag()])
  |> should.equal(Ok(Help(
    "cmd1
This is cmd1

USAGE:
\tgleam run cmd1 [ ARGS ] [ --flag2=<INT> --flag5=<FLOAT_LIST> --global=<STRING> ]

FLAGS:
\t--flag2=<INT>\t\tThis is flag2
\t--flag5=<FLOAT_LIST>\t\tThis is flag5
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information

SUBCOMMANDS:
\tcmd3\t\tThis is cmd3
\tcmd4\t\tThis is cmd4",
  )))

  // help message for nested command
  glint.execute(cli, ["cmd1", "cmd4", glint.help_flag()])
  |> should.equal(Ok(Help(
    "cmd1 cmd4
This is cmd4

USAGE:
\tgleam run cmd1 cmd4 [ ARGS ] [ --flag4=<FLOAT> --global=<STRING> ]

FLAGS:
\t--flag4=<FLOAT>\t\tThis is flag4
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information",
  )))

  // help message for command with no additional flags
  glint.execute(cli, ["cmd2", glint.help_flag()])
  |> should.equal(Ok(Help(
    "cmd2
This is cmd2

USAGE:
\tgleam run cmd2 [ ARGS ] [ --global=<STRING> ]

FLAGS:
\t--global=<STRING>\t\tThis is a global flag
\t--help\t\t\tPrint help information",
  )))
}

pub fn global_flags_test() {
  let cli =
    glint.new()
    |> glint.with_global_flag(
      "f",
      flag.I
      |> flag.default(2)
      |> flag.new
      |> flag.desc("global flag example"),
    )
    |> glint.add(
      [],
      glint.cmd(fn(ctx) {
        flag.get_int(ctx.flags, "f")
        |> should.equal(Ok(2))
      }),
    )
    |> glint.add(
      ["sub"],
      glint.cmd(fn(ctx) {
        flag.get_bool(ctx.flags, "f")
        |> should.equal(Ok(True))
      })
      |> glint.flag(
        "f",
        flag.B
        |> flag.default(True)
        |> flag.new
        |> flag.desc("i decided to override the global flag"),
      ),
    )

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
}

pub fn default_pretty_help_test() {
  // default_pretty_help has asserts
  // we need to call the function to make sure it does not crash
  glint.default_pretty_help()
}
