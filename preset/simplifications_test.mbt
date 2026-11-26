///|
test "comment and else-if boundaries keep diagnostics without edits" {
  let config = @preset.with_simplifications(@core.Config())
  let source =
    #|fn f(a : Bool, b : Bool) -> Bool {
    #|  ignore(if a {
    #|    // Preserve the branch note.
    #|    true
    #|  } else { false })
    #|  ignore(match b {
    #|    true => true
    #|    // Preserve the arm note.
    #|    false => false
    #|  })
    #|  ignore(b is // Preserve the pattern note.
    #|    false)
    #|  if a { a } else if b { true } else { false }
    #|}
  let fixed = config.fix(path="sample.mbt", source~)
  assert_eq(fixed.source, source)
  assert_eq(fixed.applied, 0)
  assert_false(fixed.rejected)
  assert_true(fixed.diagnostics.all(d => d.fix is None))
  assert_eq(fixed.diagnostics.map(d => d.rule_id), [
    Some("simplify-bool-if"),
    Some("simplify-bool-match"),
    Some("redundant-bool-pattern"),
    Some("simplify-bool-if"),
  ])
}

///|
test "Boolean fixes apply to an mbtx body after Unicode text" {
  let config = @preset.with_simplifications(@core.Config())
  let source =
    #|---
    #|import {}
    #|---
    #|fn main {
    #|  println("🍠"); println(if get_bool() { true } else { false })
    #|}
    #|fn get_bool() -> Bool { true }
  let fixed = config.fix(path="sample.mbtx", source~)
  assert_eq(fixed.applied, 1)
  assert_eq(
    fixed.source,
    (
      #|---
      #|import {}
      #|---
      #|fn main {
      #|  println("🍠"); println(((get_bool()) : Bool))
      #|}
      #|fn get_bool() -> Bool { true }
    ),
  )
  assert_true(fixed.diagnostics.is_empty())
}
