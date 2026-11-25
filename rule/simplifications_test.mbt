///|
test "simplify-bool-if fixes opposite branches without duplicating the condition" {
  let config = @core.Config().with_rule(@rule.simplify_bool_if())
  let source =
    #|fn value() -> Bool { true }
    #|fn f(a : Bool, b : Bool) -> Bool {
    #|  let first = if value() || a { true } else { false }
    #|  first && (if a && b { false } else { true })
    #|}
  let findings = config.lint(path="sample.mbt", source~)
  assert_eq(findings.map(d => d.rule_id), [
    Some("simplify-bool-if"),
    Some("simplify-bool-if"),
  ])
  assert_eq(findings.map(d => d.loc.start.lnum), [3, 4])
  let fixed = config.fix(path="sample.mbt", source~)
  assert_eq(fixed.applied, 2)
  assert_eq(
    fixed.source,
    (
      #|fn value() -> Bool { true }
      #|fn f(a : Bool, b : Bool) -> Bool {
      #|  let first = ((value() || a) : Bool)
      #|  first && ((!(a && b)))
      #|}
    ),
  )
  assert_true(fixed.diagnostics.is_empty())
}

///|
test "simplify-bool-if excludes identical branches, side effects and literal conditions" {
  let config = @core.Config().with_rule(@rule.simplify_bool_if())
  let source =
    #|fn f(b : Bool) -> Bool {
    #|  ignore(if b { true } else { true })
    #|  ignore(if b { println("effect"); true } else { false })
    #|  ignore(if true { true } else { false })
    #|  if b { true } else { b }
    #|}
  assert_true(config.lint(path="sample.mbt", source~).is_empty())
}

///|
test "simplify-bool-match fixes identity and inverted matches for both arm orders" {
  let config = @core.Config().with_rule(@rule.simplify_bool_match())
  let source =
    #|fn f(a : Bool, b : Bool) -> (Bool, Bool) {
    #|  let first = match a {
    #|    true => true
    #|    false => false
    #|  }
    #|  let second = match a || b {
    #|    false => true
    #|    true => false
    #|  }
    #|  (first, second)
    #|}
  let fixed = config.fix(path="sample.mbt", source~)
  assert_eq(fixed.applied, 2)
  assert_eq(
    fixed.source,
    (
      #|fn f(a : Bool, b : Bool) -> (Bool, Bool) {
      #|  let first = ((a) : Bool)
      #|  let second = (!(a || b))
      #|  (first, second)
      #|}
    ),
  )
  assert_true(fixed.diagnostics.is_empty())
}

///|
test "simplify-bool-match leaves guarded and binding patterns alone" {
  let config = @core.Config().with_rule(@rule.simplify_bool_match())
  let source =
    #|fn f(a : Bool, b : Bool) -> (Bool, Bool) {
    #|  let first = match a { true if b => true; _ => false }
    #|  let second = match a { true as x => x; false => false }
    #|  (first, second)
    #|}
  assert_true(config.lint(path="sample.mbt", source~).is_empty())
}

///|
test "redundant-bool-pattern fixes bare Boolean tests and leaves other patterns alone" {
  let config = @core.Config().with_rule(@rule.redundant_bool_pattern())
  let source =
    #|fn f(b : Bool, maybe : Int?) -> Bool {
    #|  if b is true { maybe is Some(_) } else { b is false }
    #|}
  let fixed = config.fix(path="sample.mbt", source~)
  assert_eq(fixed.applied, 2)
  assert_eq(
    fixed.source,
    (
      #|fn f(b : Bool, maybe : Int?) -> Bool {
      #|  if ((b) : Bool) { maybe is Some(_) } else { (!(b)) }
      #|}
    ),
  )
  assert_true(fixed.diagnostics.is_empty())
}

///|
test "constant-condition reports literal control flow but skips intentional infinite while loops" {
  let config = @core.Config().with_rule(@rule.constant_condition())
  let source =
    #|fn f(b : Bool) -> Unit {
    #|  if (true) { ignore(b) }
    #|  guard false else { return }
    #|  while false { break }
    #|  while true { break }
    #|  for i = 0; true; i = i + 1 { break }
    #|  if b { ignore(b) }
    #|}
  let findings = config.lint(path="sample.mbt", source~)
  assert_eq(findings.map(d => d.rule_id), [
    Some("constant-condition"),
    Some("constant-condition"),
    Some("constant-condition"),
    Some("constant-condition"),
  ])
  assert_eq(findings.map(d => d.loc.start.lnum), [2, 3, 4, 6])
  assert_true(findings.all(d => d.fix is None))
}

///|
test "redundant-bool-operand reports identity but not short circuit gates" {
  let config = @core.Config().with_rule(@rule.redundant_bool_operand())
  let source =
    #|fn f(b : Bool) -> Unit {
    #|  ignore(true && b)
    #|  ignore(b && true)
    #|  ignore(false || b)
    #|  ignore(b || false)
    #|  ignore(b && false)
    #|  ignore(b || true)
    #|  ignore(true || b)
    #|  ignore(false && b)
    #|}
  let findings = config.lint(path="sample.mbt", source~)
  assert_eq(findings.length(), 4)
  assert_true(
    findings.all(d => {
      d.rule_id == Some("redundant-bool-operand") && d.fix is None
    }),
  )
  assert_eq(findings.map(d => d.loc.start.lnum), [2, 3, 4, 5])
}

///|
test "no-self-assignment excludes augmented, field and indexed writes" {
  let config = @core.Config().with_rule(@rule.no_self_assignment())
  let source =
    #|struct Box { mut item : Int }
    #|fn f(b : Box, items : Array[Int]) -> Int {
    #|  let mut x = 1
    #|  x = (x)
    #|  x += x
    #|  x = x + 1
    #|  b.item = b.item
    #|  items[0] = items[0]
    #|  x
    #|}
  let findings = config.lint(path="sample.mbt", source~)
  assert_eq(findings.map(d => d.rule_id), [Some("no-self-assignment")])
  assert_eq(findings[0].loc.start.lnum, 4)
  assert_true(findings[0].fix is None)
}
