if erlang {
  import glint/style
  import gleeunit/should

  pub fn lookups_test() {
    let pretty =
      style.PrettyHelp(usage: ["1"], flags: ["2"], subcommands: ["3"])

    pretty
    |> style.lookups()
    |> style.heading("test", "usage")
    |> should.equal("\e[1;3;4;1mtest\e[0m\e[K")

    pretty
    |> style.lookups()
    |> style.heading("test", "subcommands")
    |> should.equal("\e[1;3;4;3mtest\e[0m\e[K")

    pretty
    |> style.lookups()
    |> style.heading("test", "flags")
    |> should.equal("\e[1;3;4;2mtest\e[0m\e[K")
  }
}
