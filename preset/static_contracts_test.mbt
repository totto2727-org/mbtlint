///|
test "static contracts: disabled by default, warning configurable and pack has no edits" {
  let source =
    #|fn read_config() -> String { try read() catch { _ => "" } }
    #|fn try_read_config() -> String { abort("cannot read") }
    #|fn parse_config(value : String) -> String { println(value); value }
  let base = @core.Config()
  assert_eq(base.lint(path="sample.mbt", source~).length(), 0)
  let recommended = @preset.recommended().lint(path="sample.mbt", source~)
  assert_false(
    recommended.any(d => {
      d.rule_id
      is Some("catch-hides-failure" | "safe-name-is-safe" | "pure-name-is-pure")
    }),
  )
  let findings = @preset.with_static_contracts(base)
    .with_rule(@rule.safe_name_is_safe(), severity=Warning)
    .lint(path="sample.mbt", source~)
  assert_eq(
    findings.map(d => (d.rule_id, d.severity is Warning, d.fix is None)),
    [
      (Some("catch-hides-failure"), false, true),
      (Some("safe-name-is-safe"), true, true),
      (Some("pure-name-is-pure"), false, true),
    ],
  )
}
