//// Stable, public introspection API for glint command trees.
////
//// This module exposes the shared public help types (`Metadata`, `Flag`,
//// and `ArgsCount`) used when rendering help text and, in future, when
//// auto-generating reference documentation from a command tree.

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
