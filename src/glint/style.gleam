import shellout
import gleam/map

/// Colour configuration type for help text headings.
/// the List(String) values can be RGB colour values or ANSI colour codes
/// 
pub type PrettyHelp {
  PrettyHelp(
    usage: List(String),
    flags: List(String),
    subcommands: List(String),
  )
}

/// Key for looking up the style of the usage heading
///
pub const usage_key = "usage"

/// Key for looking up the style of the flags heading
///
pub const flags_key = "flags"

/// Key for looking up the style of the subcommands heading
///
pub const subcommands_key = "subcommands"

/// Create shellout lookups from the provided pretty help
/// this is only intended for use within glint itself.
///
pub fn lookups(pretty: PrettyHelp) -> shellout.Lookups {
  [
    #(
      ["color", "background"],
      [
        #(usage_key, pretty.usage),
        #(flags_key, pretty.flags),
        #(subcommands_key, pretty.subcommands),
      ],
    ),
  ]
}

const heading_display: List(String) = ["bold", "italic", "underline"]

/// Style heading text with the provided lookups
/// this is only intended for use within glint itself.
///
pub fn heading(
  lookups: shellout.Lookups,
  heading: String,
  colour: String,
) -> String {
  shellout.display(heading_display)
  |> map.merge(shellout.color([colour]))
  |> shellout.style(heading, with: _, custom: lookups)
}
