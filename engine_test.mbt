///|
test "only a nested placeholder expression triggers no-todo" {
  let source = "fn f(x : Bool) -> String {\n  // ...\n  if x { \"...\" } else { ... }\n}"
  let findings = @mbtlint.Config::recommended().lint(path="sample.mbt", source~)
  assert_eq(findings.length(), 1)
  assert_eq(
    Show::to_string(findings[0]),
    "sample.mbt:3:25: error [no-todo] Replace the placeholder with an implementation.",
  )
}

///|
test "duplicate named tests are file-local and anonymous tests do not conflict" {
  let config = @mbtlint.Config::recommended()
  let source = "test \"one\" {}\ntest {}\ntest {}\ntest \"one\" {}"
  let findings = config.lint(path="a.mbt", source~)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].rule_id, Some("no-duplicate-test-name"))
  assert_eq(findings[0].loc.start.lnum, 4)
  assert_true(config.lint(path="b.mbt", source="test \"one\" {}").is_empty())
}

///|
test "native rules see real nested AST nodes and keep mbtx body positions" {
  let rule = @mbtlint.Rule("project/no-print", ctx => {
    @mbtlint.Listener(on_expr=expr => {
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
  let config = @mbtlint.Config()
    .with_rule(rule)
    .with_rule(rule, severity=Warning)
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
  let config = @mbtlint.Config().with_rule(
    @mbtlint.Rule("unreachable", _ => abort("Rule ran on invalid AST")),
  )
  let findings = config.lint(path="broken.mbt", source="fn {")
  assert_true(!findings.is_empty())
  for d in findings {
    assert_true(d.rule_id is None && d.severity == Error)
    assert_eq(d.path, "broken.mbt")
  }
}
