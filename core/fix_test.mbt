///|
fn replace_number(id : String, text : String) -> @core.Rule {
  @core.Rule(id, ctx => {
    @core.Listener(on_expr=expr => {
      if expr is Constant(c=Int("1"), loc~) {
        (ctx.report_fix)(loc, "Replace one", text)
      }
    })
  })
}

///|
test "ties go to the first registered fix and disjoint edits still apply" {
  let config = @core.Config()
    .with_rule(replace_number("two", "2"))
    .with_rule(replace_number("three", "3"))
  let result = config.fix(path="a.mbt", source="let x = (1, 1)")
  assert_eq(result.source, "let x = (2, 2)")
  assert_eq(result.applied, 2)
}

///|
test "reject a batch that introduces a parse error" {
  let config = @core.Config().with_rule(replace_number("broken", "("))
  let source = "let x = 1"
  let result = config.fix(path="a.mbt", source~)
  assert_true(result.rejected)
  assert_eq(result.source, source)
  assert_eq(result.applied, 0)
  assert_eq(result.diagnostics[0].rule_id, Some("broken"))
}
