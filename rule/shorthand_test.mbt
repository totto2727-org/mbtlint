///|
test "apply field and labelled argument shorthand after a Unicode header and comment" {
  let config = @core.Config()
    .with_rule(@rule.prefer_label_pun())
    .with_rule(@rule.prefer_field_pun())
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
  let config = @core.Config()
    .with_rule(@rule.prefer_label_pun())
    .with_rule(@rule.prefer_field_pun())
  let source = "fn f() { obj.call(x=// keep this\n x, y=@pkg.y); Type::{ x: y, z: @pkg.z } }"
  let result = config.fix(path="a.mbt", source~)
  assert_eq(result.source, source)
  assert_eq(result.applied, 0)
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].rule_id, Some("prefer-label-pun"))
}
