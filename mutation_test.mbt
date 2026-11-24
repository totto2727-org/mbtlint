///|
test "no-mut checks record, enum and local bindings but never removes a mut token" {
  let source = "struct Counter { mut value : Int }\nenum State { Open(mut hits~ : Int) }\nfn f() { let mut x = 0; x += 1 }"
  let config = @mbtlint.Config().with_rule(@mbtlint.no_mut())
  let result = config.fix(path="example.mbt", source~)
  assert_eq(result.source, source)
  assert_eq(result.diagnostics.map(d => (d.rule_id, d.loc.start.lnum)), [(Some("no-mut"), 1), (Some("no-mut"), 2), (Some("no-mut"), 3)])
  assert_true(config.lint(path="x.mbt", source="// let mut x = 1\nlet x = \"mut\"").is_empty())
}
