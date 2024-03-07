# Changelog

## [Unreleased](https://github.com/TanklesXL/glint/compare/v0.18.0...HEAD)

## [0.18.0](https://github.com/TanklesXL/glint/compare/v0.17.1...v0.18.0)

- support for group flags at a given path

## [0.17.1](https://github.com/TanklesXL/glint/compare/v0.17.0...v0.17.1)

- remove unused function import to silence compiler warnings

## [0.17.0](https://github.com/TanklesXL/glint/compare/v0.16.0...v0.17.0)

- support gleam 1.0.0

## [0.16.0](https://github.com/TanklesXL/glint/compare/v0.15.0...v0.16.0)

- `glint.CommandResult(a)` is now a `Result(Out(a), String)` instead of a `Result(Out(a),Snag)`
- command exectution failures due to things like invalid flags or too few args now print help text for the current command
- fix help text formatting for commands that do not include arguments
- remove named args from help text usage
- change `glint.count_args` to `glint.unnamed_args`, behaviour changes for this function to explicitly only check the number of unnamed arguments
- remove notes section from usage text

## [0.15.0](https://github.com/TanklesXL/glint/compare/v0.14.0...v0.15.0)

- support gleam >=0.34 or 1.0.x
- refactor of help generation logic, no change to help text output
- the `glint/flag` module loses the `flags_help` and `flag_type_help` functions
- the `glint` module gains the ArgsCount type and the `count_args` function to support exact and minimum arguments count
- the `glint` module gains the `named_args` function to support named arguments
- the `glint.CommandInput` type gains the `.named_args` field to access named arguments
- help text has been updated to support named and counted arguments

## [0.14.0](https://github.com/TanklesXL/glint/compare/v0.13.0...v0.14.0)

- updated to work with gleam 0.33
- removed deprecated stub api

## [0.13.0](https://github.com/TanklesXL/glint/compare/v0.12.0...v0.13.0)

- clean up `flag.get_*` and `flag.get_*_values` functions
- update to gleam 0.32

## [0.12.0](https://github.com/TanklesXL/glint/compare/v0.11.3...v0.12.0)

- update to gleam v0.20
- `flag` module now provides a getter per flag type instead of a unified one that previously returned the `Value` type.
- `glint` gains the `with_print_output` function to allow printing of command output when calling `run`.
- new builder api for commands and flags:
  - `glint.cmd` to create a command
  - `glint.description` to attach a description to a command
  - `glint.flag` to attach a flag to a command
  - `flag.{int, float, int_list, float_list, string, string_list, bool}` to initialize flag builders
  - `flag.default` to attach a default value to a flag
  - `flag.constraint` to attach a constraint to a flag
- rename `glint.with_global_flags` to `glint.global_flags`
- `glint` gains the `global_flag` and `flag_tuple` functions.

## [0.11.3](https://github.com/TanklesXL/glint/compare/v0.11.2...v0.11.3)

- fixes string concat precedence bug

## [0.11.2](https://github.com/TanklesXL/glint/compare/v0.11.1...v0.11.2)

- works on gleam 0.27

## [0.11.1](https://github.com/TanklesXL/glint/compare/v0.11.0...v0.11.1) - 2023-03-16

- make `glint/flag.Contents` non-opaque.

## [0.11.0](https://github.com/TanklesXL/glint/compare/v0.10.0...v0.11.0) - 2023-02-08

- colour for pretty help leverages the new `gleam_community/colour` and `gleam_community/ansi` packages.

## [0.10.0](https://github.com/TanklesXL/glint/compare/v0.9.0...v0.10.0) - 2022-11-29

- use gleam's new `<>` string concat operator
- use gleam's new `use` keyword for callback declaration

## [0.9.0](https://github.com/TanklesXL/glint/compare/v0.8.0...v0.9.0) - 2022-09-16

- help text can now be set to use configurable shell colours.
- added the `style` module to handle coloured help output
- `glint` gains the `Glint(a)` wrapper type
- `glint` gains the `Config` type
- `glint.new` returns a `Glint(a)` instead of a `Command(a)`
- `glint` gains helpers such as `with_config`, `default_config`, and `with_pretty_help`
- `flag.get_value` renamed to `flag.get`
- `glint` gains global flag support, with `glint.global_flags`

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
- rename `flag.FlagValue` to `flag.Internal`
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
