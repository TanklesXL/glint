import gleam/result
import gleeunit
import gleeunit/should
import glint.{CommandInput}
import glint/flag
import gleam/function
import snag

pub fn main() {
  gleeunit.main()
}

pub fn path_clean_test() {
  glint.new()
  |> glint.add_command(["", " ", " cmd", "subcmd\t"], fn(_) { Nil }, [], "", "")
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
    used: "",
  )
  |> glint.execute([])
  |> should.be_ok()

  // expecting some args
  let args = ["arg1", "arg2"]
  let is_args = fn(in: CommandInput) { should.equal(in.args, args) }

  glint.new()
  |> glint.add_command(at: [], do: is_args, with: [], described: "", used: "")
  |> glint.execute(args)
  |> should.be_ok()
}

pub fn command_routing_test() {
  let args = ["arg1", "arg2"]
  let is_args = fn(in: CommandInput) { should.equal(in.args, args) }

  let has_subcommand =
    glint.new()
    |> glint.add_command(["subcommand"], is_args, [], "", "")

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
    |> glint.add_command(["subcommand"], is_args, [], "", "")
    |> glint.add_command(["subcommand", "subsubcommand"], is_args, [], "", "")

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
      used: "",
    )
    |> glint.add_command(
      at: ["subcommand"],
      do: fn(_) { snag.error("failed") },
      with: [],
      described: "",
      used: "",
    )

  // command returns its own successful result
  cmd
  |> glint.execute([])
  |> should.equal(Ok(Ok("success")))

  // command returns its own error result
  cmd
  |> glint.execute(["subcommand"])
  |> should.equal(Ok(snag.error("failed")))
}

pub fn help_test() {
  let nil = function.constant(Nil)
  let cli =
    glint.new()
    |> glint.add_command(
      at: [],
      do: nil,
      with: [flag.string("flag1", "a", "This is flag1")],
      described: "This is the root command",
      used: "gleam run <FLAGS>",
    )
    |> glint.add_command(
      at: ["cmd1"],
      do: nil,
      with: [
        flag.string("flag2", "a", "This is flag2"),
        flag.string("flag5", "a", "This is flag5"),
      ],
      described: "This is cmd1",
      used: "gleam run cmd1 <FLAGS>",
    )
    |> glint.add_command(
      at: ["cmd1", "cmd3"],
      do: nil,
      with: [flag.string("flag3", "a", "This is flag3")],
      described: "This is cmd3",
      used: "gleam run cmd1 cmd3",
    )
    |> glint.add_command(
      at: ["cmd1", "cmd4"],
      do: nil,
      with: [flag.string("flag4", "a", "This is flag4")],
      described: "This is cmd4",
      used: "gleam run cmd1 cmd4",
    )
    |> glint.add_command(
      at: ["cmd2"],
      do: nil,
      with: [flag.string("flag6", "a", "This is flag6")],
      described: "This is cmd2",
      used: "gleam run cmd2",
    )

  glint.execute(cli, [])
  |> should.equal(Ok(Nil))

  glint.execute(cli, [flag.help_flag()])
  |> should.equal(Error(glint.Help(
    "\nThis is the root command

USAGE:
\tgleam run <FLAGS>

FLAGS:
\t--flag1=<FLAG1>\t\tThis is flag1

SUBCOMMANDS:
\tcmd1\t\tThis is cmd1
\tcmd2\t\tThis is cmd2",
  )))

  glint.execute(cli, ["cmd1", flag.help_flag()])
  |> should.equal(Error(glint.Help(
    "cmd1
This is cmd1

USAGE:
\tgleam run cmd1 <FLAGS>

FLAGS:
\t--flag2=<FLAG2>\t\tThis is flag2
\t--flag5=<FLAG5>\t\tThis is flag5

SUBCOMMANDS:
\tcmd3\t\tThis is cmd3
\tcmd4\t\tThis is cmd4",
  )))
}
