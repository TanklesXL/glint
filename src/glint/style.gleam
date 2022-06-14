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

/// Default pretty help heading colouring
/// mint colour for usage
/// pink colour for flags
/// buttercup colour for subcommands
///
pub const default_pretty_help = PrettyHelp(
  usage: ["182", "255", "234"],
  flags: ["255", "175", "243"],
  subcommands: ["252", "226", "174"],
)

/// key for looking up the style of the usage heading
///
pub const usage_key = "usage"

/// key for looking up the style of the flags heading
///
pub const flags_key = "flags"

/// key for looking up the style of the subcommands heading
///
pub const subcommands_key = "subcommands"

/// create shellout lookups from the provided pretty help
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

/// style heading text with the provided lookups
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

// bold and italic are built-in to shellout so we don't need to define them ourselves
const err_display: List(String) = ["bold", "italic"]

// brightred is built-in to shellout so we don't need to define it ourselves
const err_colours: List(String) = ["brightred"]

pub fn err_style(s: String) {
  shellout.display(err_display)
  |> map.merge(shellout.color(err_colours))
  |> shellout.style(s, _, [])
}
