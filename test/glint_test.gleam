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
  |> glint.add_command(["", " ", " cmd", "subcmd\t"], fn(_) { Nil }, [], "")
  |> glint.execute(["cmd", "subcmd"])
  |> should.be_ok()
}

pub fn root_command_test() {
  // expecting no args
  glint.new()
  |> glint.add_command(
    at: [],
    do: fn(in: CommandInput) { should.equal(in.args, []) },
    with: [],
    described: "",
  )
  |> glint.execute([])
  |> should.be_ok()

  // expecting some args
  let args = ["arg1", "arg2"]
  let is_args = fn(in: CommandInput) { should.equal(in.args, args) }

  glint.new()
  |> glint.add_command(at: [], do: is_args, with: [], described: "")
  |> glint.execute(args)
  |> should.be_ok()
}

pub fn command_routing_test() {
  let args = ["arg1", "arg2"]
  let is_args = fn(in: CommandInput) { should.equal(in.args, args) }

  let has_subcommand =
    glint.new()
    |> glint.add_command(["subcommand"], is_args, [], "")

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
    |> glint.add_command(["subcommand"], is_args, [], "")
    |> glint.add_command(["subcommand", "subsubcommand"], is_args, [], "")

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
    |> glint.add_command(
      at: [],
      do: fn(_) { Ok("success") },
      with: [],
      described: "",
    )
    |> glint.add_command(
      at: ["subcommand"],
      do: fn(_) { snag.error("failed") },
      with: [],
      described: "",
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
  let global_flags = [flag.string("global", "test", "This is a global flag")]
  let flag_1 = flag.string("flag1", "a", "This is flag1")
  let flag_2 = flag.int("flag2", 1, "This is flag2")
  let flag_3 = flag.bool("flag3", True, "This is flag3")
  let flag_4 = flag.float("flag4", 1.0, "This is flag4")
  let flag_5 = flag.floats("flag5", [1.0, 2.0], "This is flag5")

  let cli =
    glint.new()
    |> glint.with_global_flags(global_flags)
    |> glint.add_command(
      at: [],
      do: nil,
      with: [flag_1],
      described: "This is the root command",
    )
    |> glint.add_command(
      at: ["cmd1"],
      do: nil,
      with: [flag_2, flag_5],
      described: "This is cmd1",
    )
    |> glint.add_command(
      at: ["cmd1", "cmd3"],
      do: nil,
      with: [flag_3],
      described: "This is cmd3",
    )
    |> glint.add_command(
      at: ["cmd1", "cmd4"],
      do: nil,
      with: [flag_4],
      described: "This is cmd4",
    )
    |> glint.add_command(
      at: ["cmd2"],
      do: nil,
      with: [],
      described: "This is cmd2",
    )
    |> glint.add_command(
      at: ["cmd5", "cmd6"],
      do: nil,
      with: [],
      described: "This is cmd6",
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
\t--help\t\t\tPrint help information
\t--flag1=<STRING>\t\tThis is flag1
\t--global=<STRING>\t\tThis is a global flag

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
\t--help\t\t\tPrint help information
\t--flag2=<INT>\t\tThis is flag2
\t--flag5=<FLOAT_LIST>\t\tThis is flag5
\t--global=<STRING>\t\tThis is a global flag

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
\t--help\t\t\tPrint help information
\t--flag4=<FLOAT>\t\tThis is flag4
\t--global=<STRING>\t\tThis is a global flag",
  )))

  // help message for command with no additional flags
  glint.execute(cli, ["cmd2", glint.help_flag()])
  |> should.equal(Ok(Help(
    "cmd2
This is cmd2

USAGE:
\tgleam run cmd2 [ ARGS ] [ --global=<STRING> ]

FLAGS:
\t--help\t\t\tPrint help information
\t--global=<STRING>\t\tThis is a global flag",
  )))
}

if erlang {
  pub fn pretty_help_test() {
    glint.new()
    |> glint.with_pretty_help(glint.default_pretty_help)
    |> glint.add_command(
      [],
      fn(_) { Nil },
      [],
      "this is the root command, it doesn't do anyhting",
    )
    |> glint.add_command(
      ["subcommand"],
      fn(_) { Nil },
      [],
      "this is the subcommand, it doesn't do anything either",
    )
    |> glint.execute(["--help"])
    |> should.equal(Ok(Help(
      "this is the root command, it doesn't do anyhting

\e[1;3;4;38;2;182;255;234mUSAGE:\e[0m\e[K
\tgleam run [ ARGS ]

\e[1;3;4;38;2;255;175;243mFLAGS:\e[0m\e[K
\t--help\t\t\tPrint help information

\e[1;3;4;38;2;252;226;174mSUBCOMMANDS:\e[0m\e[K
\tsubcommand\t\tthis is the subcommand, it doesn't do anything either",
    )))
  }
}

pub fn global_flags_test() {
  let cli =
    glint.new()
    |> glint.with_global_flags([flag.int("f", 1, "global flag example")])
    |> glint.add_command(
      [],
      fn(ctx) {
        flag.get(ctx.flags, "f")
        |> should.equal(Ok(flag.I(2)))
      },
      [],
      "",
    )
    |> glint.add_command(
      ["sub"],
      fn(ctx) {
        flag.get(ctx.flags, "f")
        |> should.equal(Ok(flag.B(True)))
      },
      [flag.bool("f", False, "i decided to override the global flag")],
      "",
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
