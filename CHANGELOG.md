# Changelog

## [Unreleased]

- rename flag `*_list` functions
- rename `flag.FlagValue` to `flag.Value`
- rename `flag.FlagMap` to `flag.Map`

## [0.6.0] - 2022-02-11

- `Runner` returns a generic type
- sanitize command paths
- make flag prefix a const
- make flag delimiter a const

## [0.5.0] - 2022-01-31

- boolean flag toggle support added

## [0.4.0] - 2022-01-28

- flag string chopping has been moved into `flag` module
- flags are split from args list, so flags are no longer positionally dependent
- `flag` parsing functions share common bases `parse_flag` and `parse_list_flag`

## [0.3.0] - 2022-01-13

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

[Unreleased]: https://github.com/TanklesXL/glint/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/TanklesXL/glint/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/TanklesXL/glint/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/TanklesXL/glint/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/TanklesXL/glint/compare/v0.2.0...v0.3.0
