import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import glint
import glint/help

fn nil_command() {
  glint.command(fn(_, _, _) { Nil })
}

fn flag_named(flags: List(help.Flag), name: String) -> help.Flag {
  let assert [flag] = list.filter(flags, fn(flag) { flag.meta.name == name })
  flag
}

fn tree_named(trees: List(help.Tree), name: String) -> help.Tree {
  let assert [tree] = list.filter(trees, fn(tree) { tree.meta.name == name })
  tree
}

pub fn empty_glint_documents_empty_tree_test() {
  let tree = glint.new() |> glint.document

  tree.meta.name
  |> should.equal("")

  tree.flags
  |> should.equal([])

  tree.subcommands
  |> should.equal([])

  tree.unnamed_args
  |> should.equal(None)

  tree.named_args
  |> should.equal([])
}

pub fn with_name_sets_root_tree_name_test() {
  let tree =
    glint.new()
    |> glint.with_name("myapp")
    |> glint.add(at: [], do: nil_command())
    |> glint.document

  tree.meta.name
  |> should.equal("myapp")
}

pub fn root_command_documents_help_flags_and_defaults_test() {
  let count =
    glint.int_flag("count")
    |> glint.flag_default(3)

  let label =
    glint.string_flag("label")
    |> glint.flag_default("fallback")

  let tree =
    glint.new()
    |> glint.add(at: [], do: {
      use <- glint.command_help("Root command description")
      use _count <- glint.flag(count)
      use _label <- glint.flag(label)
      nil_command()
    })
    |> glint.document

  tree.meta.description
  |> should.equal("Root command description")

  list.length(tree.flags)
  |> should.equal(2)

  let count = flag_named(tree.flags, "count")
  count.type_
  |> should.equal("INT")
  count.default
  |> should.equal(Some("3"))

  let label = flag_named(tree.flags, "label")
  label.type_
  |> should.equal("STRING")
  label.default
  |> should.equal(Some("fallback"))

  tree.subcommands
  |> should.equal([])
}

pub fn nested_commands_document_recurses_test() {
  let tree =
    glint.new()
    |> glint.add(at: [], do: nil_command())
    |> glint.add(at: ["one"], do: nil_command())
    |> glint.add(at: ["one", "two"], do: nil_command())
    |> glint.add(at: ["one", "two", "three"], do: nil_command())
    |> glint.document

  list.length(tree.subcommands)
  |> should.equal(1)

  let one = tree_named(tree.subcommands, "one")
  one.meta.name
  |> should.equal("one")

  list.length(one.subcommands)
  |> should.equal(1)

  let two = tree_named(one.subcommands, "two")
  two.meta.name
  |> should.equal("two")

  list.length(two.subcommands)
  |> should.equal(1)

  let three = tree_named(two.subcommands, "three")
  three.meta.name
  |> should.equal("three")

  three.subcommands
  |> should.equal([])
}

pub fn group_flags_document_on_leaf_commands_test() {
  let verbose =
    glint.string_flag("verbose")
    |> glint.flag_default("yes")

  let tree =
    glint.new()
    |> glint.group_flag(at: ["parent"], of: verbose)
    |> glint.add(at: ["parent", "leaf"], do: nil_command())
    |> glint.document

  let parent = tree_named(tree.subcommands, "parent")
  let leaf = tree_named(parent.subcommands, "leaf")
  let verbose = flag_named(leaf.flags, "verbose")

  verbose.type_
  |> should.equal("STRING")
  verbose.default
  |> should.equal(Some("yes"))
}
