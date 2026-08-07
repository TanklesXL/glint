//// Stable, public introspection API for glint command trees.
////
//// This module is intended for tools that auto-generate reference
//// documentation from a command tree, such as Markdown, JSON, manpages, or
//// other formats. Use `glint.document/1` as the entry point for producing
//// these public help values.

import gleam/option.{type Option}

/// Metadata shared by commands and flags: the `name` used in usage text and
/// headings, plus a human-readable `description`.
///
/// Re-declared as a fresh public type (rather than aliasing
/// `glint/internal/help.Metadata`) so downstream tools can both read and
/// construct `Metadata` values without importing `glint/internal/help`.
pub type Metadata {
  Metadata(name: String, description: String)
}

/// Number of unnamed positional arguments accepted by a command.
///
/// Re-declared (rather than aliased) so that the `EqArgs` and `MinArgs`
/// constructors are accessible without importing `glint/internal/help`.
pub type ArgsCount {
  EqArgs(Int)
  MinArgs(Int)
}

pub type Flag {
  Flag(meta: Metadata, type_: String, default: Option(String))
}

pub type Tree {
  Tree(
    meta: Metadata,
    flags: List(Flag),
    subcommands: List(Tree),
    unnamed_args: Option(ArgsCount),
    named_args: List(String),
  )
}
