# hello

This is an example project that demonstrates a simple workflow using `glint`.
It contains only one command, the root command.
Feel free to browse `src/hello.gleam` to get a sense of how a small cli application is written.

## Usage

### Running the application

You can run this example from the `examples/hello` directory by calling `gleam run` which prints `Hello, <NAMES>!`

The `hello` application accepts at least one argument, being the names of people to say hello to.

- No input: `gleam run` -> prints "Hello, Joe!"
- One input: `gleam run Joe` -> prints "Hello, Joe!"
- Two inputs: `gleam run Rob Louis` -> prints "Hello, Rob and Louis!"
- \>2 inputs: `gleam run Rob Louis Hayleigh` -> prints "Hello, Rob, Louis and Hayleigh!"

### Flags

The root command accepts two flags:

- `--caps`: capitalizes the output, so if output would be "Hello, Joe!" it prints "HELLO, JOE!"
- `--repeat=N`: repeats the output N times separated , so with N=2 if output would be "Hello, Joe!" it prints "Hello, Joe!\nHello, Joe!"

## Help Output

Generated help output for the root command is as follows

```txt
Prints Hello, <NAME>!

USAGE:
        hello [ ARGS ] [ --caps=<BOOL> --repeat=<INT> ]

FLAGS:
        --caps=<BOOL>           Capitalize the provided name
        --help                  Print help information
        --repeat=<INT>          Repeat the message n-times
```
