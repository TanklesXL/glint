# Changelog

## [Unreleased](https://github.com/TanklesXL/glint/compare/v0.8.0...HEAD)

- help text can now be set to use configurable shell colours.
- added the `style` module to handle coloured help output
- `glint` gains the `Glint(a)` wrapper type
- `glint` gains the `Config` type
- `glint.new` returns a `Glint(a)` instead of a `Command(a)`
- `glint` gains helpers such as `with_config`, `default_config`, and `with_pretty_help`
- `glint.Contents` and `glint.Command` are no longer opaque

## [0.8.0](https://github.com/TanklesXL/glint/compare/v0.7.4...v0.8.0) - 2022-05-09

- `flag.Contents` is no longer opaque
- `glint` module gains `Stub` type to create constant commands and `add_command_from_stub` to add the resulting commands

## [0.7.4](https://github.com/TanklesXL/glint/compare/v0.7.3...v0.7.4) - 2022-05-03

- refactor: negation operator in `flag.gleam` instead of bool.negate
- refactor: split `flag.update_flags` into calling `update_flag_value` or `attempt_toggle_flag`

## [0.7.3](https://github.com/TanklesXL/glint/compare/v0.7.2...v0.7.3) - 2022-02-23

- make `flag.Contents` opaque

## [0.7.2](https://github.com/TanklesXL/glint/compare/v0.7.1...v0.7.2) - 2022-02-22

- add argument labels to `flag.get_value`

## [0.7.1](https://github.com/TanklesXL/glint/compare/v0.7.0...v0.7.1) - 2022-02-22

- `flag.access_flag` renamed to `flag.access`
- `flag.get_value` added

## [0.7.0](https://github.com/TanklesXL/glint/compare/v0.6.0...v0.7.0) - 2022-02-22

- rename flag `*_list` functions
- rename `flag.FlagValue` to `flag.Value`
- rename `flag.FlagMap` to `flag.Map`
- generate help messages for commands and flags

## [0.6.0](https://github.com/TanklesXL/glint/compare/v0.5.0...v0.6.0) - 2022-02-11

- `Runner` returns a generic type
- sanitize command paths
- make flag prefix a const
- make flag delimiter a const

## [0.5.0](https://github.com/TanklesXL/glint/compare/v0.4.0...v0.5.0) - 2022-01-31

- boolean flag toggle support added

## [0.4.0](https://github.com/TanklesXL/glint/compare/v0.3.0...v0.4.0) - 2022-01-28

- flag string chopping has been moved into `flag` module
- flags are split from args list, so flags are no longer positionally dependent
- `flag` parsing functions share common bases `parse_flag` and `parse_list_flag`

## [0.3.0](https://github.com/TanklesXL/glint/compare/v0.2.0...v0.3.0) - 2022-01-13

- `flag` module gains support for float and float list flags.
- rename `FlagValue` constructors to be more concise.

## [0.2.0] - 2022-01-12

- `flag` module gains support for string list and int list flags.

## [0.1.3]

- Use `--` for flags instead of `-`.
- Add `example` directory.

## [0.1.2]

- README update.

## [0.1.1]

- refactor `gling.add_command`.

## [0.1.0]

- Initial argument parsing and flags support.
