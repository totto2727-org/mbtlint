///|
test "safety pack exempts expected panic tests and resumes on the next declaration" {
  let source =
    #|test "panic expected" {
    #|  abort("expected")
    #|  ignore(None.unwrap())
    #|  try! run()
    #|  ignore([1].unsafe_get(2))
    #|}
    #|test "panic_legacy" { panic() }
    #|test "panic" { panic() }
    #|test "panicking is not an expected panic prefix" { panic() }
    #|test { abort("unexpected") }
    #|fn f() -> Unit {
    #|  ignore(None.unwrap())
    #|  try! run()
    #|  ignore([1].unsafe_get(2))
    #|}
  let findings = @preset.with_safety(@core.Config()).lint(
    path="sample.mbt",
    source~,
  )
  assert_eq(
    findings.map(finding => (finding.rule_id, finding.loc.start.lnum)),
    [
      (Some("no-panic"), 9),
      (Some("no-panic"), 10),
      (Some("no-unsafe-unwrap"), 12),
      (Some("no-try-bang"), 13),
      (Some("no-unsafe-operations"), 14),
    ],
  )
}
