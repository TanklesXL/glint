import gleam/string
import gleeunit/should
import glint.{Help}

fn cli(show_defaults: Bool) -> glint.Glint(Nil) {
  let count =
    glint.int_flag("count")
    |> glint.flag_default(3)
    |> glint.flag_help("How many times")

  glint.new()
  |> glint.show_flag_defaults(show_defaults)
  |> glint.add(at: [], do: {
    use _count <- glint.flag(count)
    glint.command(fn(_, _, _) { Nil })
  })
}

fn help_text(g: glint.Glint(Nil)) -> String {
  let assert Ok(Help(help)) = glint.execute(g, ["--help"])
  help
}

pub fn enabled_renders_default_test() {
  cli(True)
  |> help_text
  |> string.contains("(default: 3)")
  |> should.be_true
}

pub fn disabled_omits_default_test() {
  cli(False)
  |> help_text
  |> string.contains("(default:")
  |> should.be_false
}
