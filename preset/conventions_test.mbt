///|
test "Config with_conventions - enables every rule and lets callers remove one" {
  let source =
    #|pub fn example(a : Int, b : Int, c : Int, d : Int) -> Int raise {
    #|  consume(fn(x) { x })
    #|  @fs.path_exists(parent + "/" + child)
    #|  try { action() } catch { err => raise err }
    #|}
    #|test {}
  let config = @preset.with_conventions(@core.Config())
  let ids = config.lint(path="sample.mbt", source~).map(d => d.rule_id)
  assert_eq(ids, [
    Some("require-public-docs"),
    Some("prefer-labelled-parameters"),
    Some("prefer-arrow-callback"),
    Some("no-manual-path-join"),
    Some("no-redundant-rethrow"),
    Some("require-named-tests"),
  ])
  assert_eq(
    config
    .without_rule("require-named-tests")
    .lint(path="sample.mbt", source~)
    .map(d => d.rule_id),
    ids.filter(id => id != Some("require-named-tests")),
  )
}
