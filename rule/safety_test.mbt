///|
fn safety_findings(
  rule : @core.Rule,
  source : String,
) -> Array[(String?, Int32)] {
  @core.Config()
  .with_rule(rule)
  .lint(path="sample.mbt", source~)
  .map(finding => (finding.rule_id, finding.loc.start.lnum))
}

///|
test "safety no-panic recognizes core calls and both pipe directions" {
  let source =
    #|fn f(obj : Service) -> Unit {
    #|  abort("direct")
    #|  panic()
    #|  @builtin.abort("qualified")
    #|  @prelude.panic()
    #|  @abort.abort("legacy")
    #|  "forward" |> abort
    #|  abort <| "reverse"
    #|  (abort)("grouped")
    #|  @service.abort("unrelated")
    #|  obj.panic()
    #|  ignore(abort)
    #|  ignore("panic()")
    #|}
  assert_eq(
    safety_findings(@rule.no_panic(), source),
    [2, 3, 4, 5, 6, 7, 8, 9].map(line => (Some("no-panic"), line)),
  )
}

///|
test "safety no-panic distinguishes a same-file value from an explicit core call" {
  let source =
    #|fn panic() -> Unit { () }
    #|fn f() -> Unit {
    #|  panic()
    #|  @builtin.panic()
    #|}
  assert_eq(safety_findings(@rule.no_panic(), source), [(Some("no-panic"), 4)])
}

///|
test "safety no-unsafe-unwrap detects member, static, qualified and piped unwraps" {
  let source =
    #|fn f(value : Int?, result : Result[Int, String], custom : Widget) -> Unit {
    #|  ignore(value.unwrap())
    #|  ignore(result.unwrap_err())
    #|  ignore(Option::unwrap(value))
    #|  ignore(@builtin.Result::unwrap(result))
    #|  result |> Result::unwrap_err |> ignore
    #|  ignore(@prelude.Option::unwrap <| value)
    #|  ignore(value.unwrap_or(0))
    #|  ignore(result.unwrap_or_default())
    #|  ignore(custom.unwrap(3))
    #|  ignore(Widget::unwrap(custom))
    #|  ignore(@service.Option::unwrap(value))
    #|  ignore(Option::unwrap)
    #|}
  assert_eq(
    safety_findings(@rule.no_unsafe_unwrap(), source),
    [2, 3, 4, 5, 6, 7].map(line => (Some("no-unsafe-unwrap"), line)),
  )
}

///|
test "safety no-try-bang marks the operator and leaves error handlers alone" {
  let source =
    #|---
    #|import {}
    #|---
    #|fn main {
    #|  try! run()
    #|  try run() catch { _ => () }
    #|  // try! run()
    #|  ignore("try!")
    #|}
  let findings = @core.Config()
    .with_rule(@rule.no_try_bang())
    .lint(path="lint.mbtx", source~)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].rule_id, Some("no-try-bang"))
  assert_eq(findings[0].loc.start.lnum, 5)
  assert_eq(findings[0].loc.start.column(), 3)
}

///|
test "safety no-unsafe-operations reports known core calls once without prefix matching" {
  let source =
    #|fn f(xs : Array[Int], widget : Widget, list : @list.List[Int]) -> Unit {
    #|  ignore(xs.unsafe_get(0))
    #|  ignore(Array::unsafe_get(xs, 0))
    #|  xs |> @builtin.Array::unsafe_get(0) |> ignore
    #|  list |> @list.List::unsafe_tail |> ignore
    #|  "x" |> @string.Regex::unsafe_from_string |> ignore
    #|  ignore(@prelude.String::unsafe_char_at("x", 0))
    #|  ignore(xs.get(0))
    #|  ignore(widget.unsafe_preview())
    #|  ignore(Widget::unsafe_get(widget, 0))
    #|  ignore(@service.Array::unsafe_get(xs, 0))
    #|  ignore(Array::unsafe_preview(xs))
    #|  ignore(Array::unsafe_get)
    #|}
  assert_eq(
    safety_findings(@rule.no_unsafe_operations(), source),
    [2, 3, 4, 5, 6, 7].map(line => (Some("no-unsafe-operations"), line)),
  )
}
