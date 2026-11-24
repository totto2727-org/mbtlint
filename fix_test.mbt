///|
test "apply field and labelled argument shorthand after a Unicode header and comment" {
  let config = @mbtlint.Config()
    .with_rule(@mbtlint.prefer_label_pun())
    .with_rule(@mbtlint.prefer_field_pun())
  let prefix = "---\n// 🌙\n---\n// 🛰️\n"
  let source = prefix + "fn f(x : Int) { call(x=x, opt?=opt); { x: x } }"
  let expected = prefix + "fn f(x : Int) { call(x~, opt?); { x, } }"
  let result = config.fix(path="lint.mbtx", source~)
  assert_eq(result.source, expected)
  assert_eq(result.applied, 3)
  assert_true(result.diagnostics.is_empty() && !result.rejected)
  assert_eq(config.fix(path="lint.mbtx", source=expected).applied, 0)
}

///|
test "keep comments, qualified names, and distinct arguments intact" {
  let config = @mbtlint.Config()
    .with_rule(@mbtlint.prefer_label_pun())
    .with_rule(@mbtlint.prefer_field_pun())
  let source = "fn f() { obj.call(x=// keep this\n x, y=@pkg.y); Type::{ x: y, z: @pkg.z } }"
  let result = config.fix(path="a.mbt", source~)
  assert_eq(result.source, source)
  assert_eq(result.applied, 0)
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].rule_id, Some("prefer-label-pun"))
}

///|
fn replace_number(id : String, text : String) -> @mbtlint.Rule {
  @mbtlint.Rule(id, ctx => {
    @mbtlint.Listener(on_expr=expr => {
      if expr is Constant(c=Int("1"), loc~) {
        (ctx.report_fix)(loc, "Replace one", text)
      }
    })
  })
}

///|
test "ties go to the first registered fix and disjoint edits still apply" {
  let config = @mbtlint.Config()
    .with_rule(replace_number("two", "2"))
    .with_rule(replace_number("three", "3"))
  let result = config.fix(path="a.mbt", source="let x = (1, 1)")
  assert_eq(result.source, "let x = (2, 2)")
  assert_eq(result.applied, 2)
}

///|
test "reject a batch that introduces a parse error" {
  let config = @mbtlint.Config().with_rule(replace_number("broken", "("))
  let source = "let x = 1"
  let result = config.fix(path="a.mbt", source~)
  assert_true(result.rejected)
  assert_eq(result.source, source)
  assert_eq(result.applied, 0)
  assert_eq(result.diagnostics[0].rule_id, Some("broken"))
}
