///|
test "only a nested placeholder expression triggers no-todo" {
  let source = "fn f(x : Bool) -> String {\n  // ...\n  if x { \"...\" } else { ... }\n}"
  let findings = @preset.recommended().lint(path="sample.mbt", source~)
  assert_eq(findings.length(), 1)
  assert_eq(
    Show::to_string(findings[0]),
    "sample.mbt:3:25: error [no-todo] Replace the placeholder with an implementation.",
  )
}

///|
test "duplicate named tests are file-local and anonymous tests do not conflict" {
  let config = @preset.recommended()
  let source = "test \"one\" {}\ntest {}\ntest {}\ntest \"one\" {}"
  let findings = config.lint(path="a.mbt", source~)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].rule_id, Some("no-duplicate-test-name"))
  assert_eq(findings[0].loc.start.lnum, 4)
  assert_true(config.lint(path="b.mbt", source="test \"one\" {}").is_empty())
}
