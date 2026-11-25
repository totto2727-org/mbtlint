///|
test "native rules see real nested AST nodes and keep mbtx body positions" {
  let rule = @core.Rule("project/no-print", ctx => {
    @core.Listener(on_expr=expr => {
      if expr
        is Apply(
          func=Ident(id={ name: Ident(name="println"), .. }, ..),
          loc~,
          ..
        ) {
        (ctx.report)(loc, "Use the project logger.")
      }
    })
  })
  let source = "---\nimport {}\n---\nfn main {\n  if true { println(1) }\n}"
  let config = @core.Config().with_rule(rule).with_rule(rule, severity=Warning)
  let findings = config.lint(path="lint.mbtx", source~)
  assert_eq(findings.length(), 1)
  assert_eq(
    Show::to_string(findings[0]),
    "lint.mbtx:5:13: warning [project/no-print] Use the project logger.",
  )
  assert_true(
    config.without_rule(rule.id).lint(path="lint.mbtx", source~).is_empty(),
  )
  assert_eq(config.lint(path="lint.mbtx", source~).length(), 1)
}

///|
test "a parser failure is reported even without rules and does not invoke a rule" {
  let config = @core.Config().with_rule(
    @core.Rule("unreachable", _ => abort("Rule ran on invalid AST")),
  )
  let findings = config.lint(path="broken.mbt", source="fn {")
  assert_true(!findings.is_empty())
  for d in findings {
    assert_true(d.rule_id is None && d.severity == Error)
    assert_eq(d.path, "broken.mbt")
  }
}
