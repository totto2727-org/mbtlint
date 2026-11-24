///|
test "simplify-bool-if fixes opposite branches without duplicating the condition" {
  let config = @mbtlint.Config().with_rule(@mbtlint.simplify_bool_if())
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
  let config = @mbtlint.Config().with_rule(@mbtlint.simplify_bool_if())
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
  let config = @mbtlint.Config().with_rule(@mbtlint.simplify_bool_match())
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
  let config = @mbtlint.Config().with_rule(@mbtlint.simplify_bool_match())
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
  let config = @mbtlint.Config().with_rule(@mbtlint.redundant_bool_pattern())
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
  let config = @mbtlint.Config().with_rule(@mbtlint.constant_condition())
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
  let config = @mbtlint.Config().with_rule(@mbtlint.redundant_bool_operand())
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
  let config = @mbtlint.Config().with_rule(@mbtlint.no_self_assignment())
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

///|
test "comment and else-if boundaries keep diagnostics without edits" {
  let config = @mbtlint.Config().with_simplifications()
  let source =
    #|fn f(a : Bool, b : Bool) -> Bool {
    #|  ignore(if a {
    #|    // Preserve the branch note.
    #|    true
    #|  } else { false })
    #|  ignore(match b {
    #|    true => true
    #|    // Preserve the arm note.
    #|    false => false
    #|  })
    #|  ignore(b is // Preserve the pattern note.
    #|    false)
    #|  if a { a } else if b { true } else { false }
    #|}
  let fixed = config.fix(path="sample.mbt", source~)
  assert_eq(fixed.source, source)
  assert_eq(fixed.applied, 0)
  assert_false(fixed.rejected)
  assert_true(fixed.diagnostics.all(d => d.fix is None))
  assert_eq(fixed.diagnostics.map(d => d.rule_id), [
    Some("simplify-bool-if"),
    Some("simplify-bool-match"),
    Some("redundant-bool-pattern"),
    Some("simplify-bool-if"),
  ])
}

///|
test "Boolean fixes apply to an mbtx body after Unicode text" {
  let config = @mbtlint.Config().with_simplifications()
  let source =
    #|---
    #|import {}
    #|---
    #|fn main {
    #|  println("🍠"); println(if get_bool() { true } else { false })
    #|}
    #|fn get_bool() -> Bool { true }
  let fixed = config.fix(path="sample.mbtx", source~)
  assert_eq(fixed.applied, 1)
  assert_eq(
    fixed.source,
    (
      #|---
      #|import {}
      #|---
      #|fn main {
      #|  println("🍠"); println(((get_bool()) : Bool))
      #|}
      #|fn get_bool() -> Bool { true }
    ),
  )
  assert_true(fixed.diagnostics.is_empty())
}
