import gleam/list
import gleam/option.{type Option, None, Some}
import gleeunit/should
import glint

fn assert_documented_default(
  flag: glint.Flag(a),
  name: String,
  expected: Option(String),
) {
  let cmd = {
    use _ <- glint.flag(flag)
    glint.command(fn(_, _, _) { Nil })
  }
  let g =
    glint.new()
    |> glint.add(at: [], do: cmd)
  let tree = glint.document(g)
  let assert Ok(f) = list.find(tree.flags, fn(f) { f.meta.name == name })

  f.default
  |> should.equal(expected)
}

pub fn int_default_stringifies_test() {
  glint.int_flag("count")
  |> glint.flag_default(42)
  |> assert_documented_default("count", Some("42"))
}

pub fn float_default_stringifies_test() {
  glint.float_flag("ratio")
  |> glint.flag_default(3.14)
  |> assert_documented_default("ratio", Some("3.14"))
}

pub fn string_default_stringifies_test() {
  glint.string_flag("greeting")
  |> glint.flag_default("hello")
  |> assert_documented_default("greeting", Some("hello"))
}

pub fn bool_true_default_stringifies_test() {
  glint.bool_flag("enabled")
  |> glint.flag_default(True)
  |> assert_documented_default("enabled", Some("true"))
}

pub fn bool_false_default_stringifies_test() {
  glint.bool_flag("disabled")
  |> glint.flag_default(False)
  |> assert_documented_default("disabled", Some("false"))
}

pub fn ints_default_stringifies_as_csv_test() {
  glint.ints_flag("counts")
  |> glint.flag_default([1, 2, 3])
  |> assert_documented_default("counts", Some("1,2,3"))
}

pub fn floats_default_stringifies_as_csv_test() {
  glint.floats_flag("ratios")
  |> glint.flag_default([1.0, 2.5])
  |> assert_documented_default("ratios", Some("1.0,2.5"))
}

pub fn strings_default_stringifies_as_csv_test() {
  glint.strings_flag("names")
  |> glint.flag_default(["a", "b", "c"])
  |> assert_documented_default("names", Some("a,b,c"))
}

pub fn flag_without_default_documents_none_test() {
  glint.int_flag("count")
  |> assert_documented_default("count", None)
}

pub fn empty_ints_default_stringifies_as_empty_string_test() {
  glint.ints_flag("counts")
  |> glint.flag_default([])
  |> assert_documented_default("counts", Some(""))
}
