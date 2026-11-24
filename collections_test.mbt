///|
fn collection_rule_ids(source : String) -> Array[String?] {
  @mbtlint.Config()
  .with_collections()
  .lint(path="sample.mbt", source~)
  .map(finding => finding.rule_id)
}

///|
test "collection construction recognizes map, filter, fused filter-map and plain transfer without overlaps" {
  let source =
    #|fn doubled(xs : Array[Int]) -> Array[Int] {
    #|  let out : Array[Int] = []
    #|  for x in xs { out.push(x * 2) }
    #|  out
    #|}
    #|fn positives(xs : Array[Int]) -> Array[Int] {
    #|  let out = []
    #|  for x in xs { if x > 0 { out.push(x) } }
    #|  out
    #|}
    #|fn positive_doubles(xs : Array[Int]) -> Array[Int] {
    #|  let out = []
    #|  for x in xs { if x > 0 { out.push(x * 2) } }
    #|  out
    #|}
    #|fn materialize(xs : Array[Int]) -> Array[Int] {
    #|  let out = []
    #|  for x in xs.iter() { out.push(x) }
    #|  out
    #|}
  let findings = @mbtlint.Config()
    .with_collections()
    .lint(path="sample.mbt", source~)
  assert_eq(findings.map(d => d.rule_id), [
    Some("prefer-collection-map"),
    Some("prefer-collection-filter"),
    Some("prefer-collection-filter"),
    Some("prefer-collection-transfer"),
  ])
  assert_eq(findings.map(d => d.loc.start.lnum), [3, 8, 13, 18])
  assert_true(findings[2].message.contains("filter_map"))
  assert_true(findings.all(d => d.severity == @mbtlint.Warning))
}

///|
test "collection construction skips saved buffers, extra effects, binding shadowing and feedback from the output" {
  let source =
    #|fn fill(xs : Array[Int], out : Array[Int]) -> Array[Int] {
    #|  for x in xs { out.push(x * 2) }
    #|  out
    #|}
    #|fn prefix(xs : Array[Int]) -> Array[Int] {
    #|  let out = [1]
    #|  for x in xs { out.push(x) }
    #|  out
    #|}
    #|fn extra(xs : Array[Int]) -> Array[Int] {
    #|  let out = []
    #|  for x in xs {
    #|    println(x)
    #|    if x > 0 { out.push(x) }
    #|  }
    #|  out
    #|}
    #|fn feedback(xs : Array[Int]) -> Array[Int] {
    #|  let out = []
    #|  for x in xs { if out.length() < 3 { out.push(x) } }
    #|  out
    #|}
    #|fn self_source() -> Array[Int] {
    #|  let out : Array[Int] = []
    #|  for x in out.iter() { out.push(x) }
    #|  out
    #|}
    #|fn shadow(xs : Array[Array[Int]]) -> Array[Int] {
    #|  let out : Array[Int] = []
    #|  for out in xs { out.push(0) }
    #|  out
    #|}
    #|fn index_range(n : Int) -> Array[Int] {
    #|  let out = []
    #|  for i in 0..<n { out.push(i * i) }
    #|  out
    #|}
  assert_eq(collection_rule_ids(source), [])
}

///|
test "collection searches distinguish existential, universal and first-match exits" {
  let source =
    #|fn has_even(xs : Array[Int]) -> Bool {
    #|  for x in xs { if x % 2 == 0 { break true } } nobreak { false }
    #|}
    #|fn all_even(xs : Array[Int]) -> Bool {
    #|  for x in xs { if x % 2 != 0 { break false } } nobreak { true }
    #|}
    #|fn first_even(xs : Array[Int]) -> Int? {
    #|  for x in xs { if x % 2 == 0 { break Some(x) } } nobreak { None }
    #|}
  assert_eq(collection_rule_ids(source), [
    Some("prefer-collection-any"),
    Some("prefer-collection-all"),
    Some("prefer-collection-find"),
  ])
}

///|
test "collection searches skip fixed fallbacks, transformed results and nonlocal control flow" {
  let source =
    #|fn always_true(xs : Array[Int]) -> Bool {
    #|  for x in xs { if x > 0 { break true } } nobreak { true }
    #|}
    #|fn always_false(xs : Array[Int]) -> Bool {
    #|  for x in xs { if x > 0 { break false } } nobreak { false }
    #|}
    #|fn transformed(xs : Array[Int]) -> Int? {
    #|  for x in xs { if x > 0 { break Some(x + 1) } } nobreak { None }
    #|}
    #|fn early_return(xs : Array[Int]) -> Bool {
    #|  for x in xs { if x > 0 { return true } } nobreak { false }
    #|}
    #|fn mixed(xs : Array[Int]) -> Bool {
    #|  for x in xs {
    #|    if x > 0 { break true }
    #|    if x < 0 { break false }
    #|  } nobreak { false }
    #|}
  assert_eq(collection_rule_ids(source), [])
}

///|
test "collection fold matches a scalar update and a single native loop accumulator" {
  let source =
    #|fn sum(xs : Array[Int]) -> Int {
    #|  let mut total = 0
    #|  for x in xs { total += x }
    #|  total
    #|}
    #|fn sum_functional(xs : Array[Int]) -> Int {
    #|  for x in xs; total = 0 { continue total + x } nobreak { total }
    #|}
  assert_eq(collection_rule_ids(source), [
    Some("prefer-collection-fold"),
    Some("prefer-collection-fold"),
  ])
}

///|
test "collection fold skips multiple updates, early exits and reassignment without the previous value" {
  let source =
    #|fn with_exit(xs : Array[Int]) -> Int {
    #|  let mut total = 0
    #|  for x in xs {
    #|    if x < 0 { break }
    #|    total += x
    #|  }
    #|  total
    #|}
    #|fn overwritten(xs : Array[Int]) -> Int {
    #|  let mut last = 0
    #|  for x in xs { last = x }
    #|  last
    #|}
    #|fn multiple(xs : Array[Int]) -> Int {
    #|  for x in xs; total = 0, count = 0 { continue total + x, count + 1 } nobreak { total + count }
    #|}
  assert_eq(collection_rule_ids(source), [])
}

///|
test "collection rules can be selected and overridden independently" {
  let source =
    #|fn mapped(xs : Array[Int]) -> Array[Int] {
    #|  let out = []
    #|  for x in xs { out.push(x * 2) }
    #|  out
    #|}
  assert_eq(@mbtlint.Config().lint(path="sample.mbt", source~).length(), 0)
  let findings = @mbtlint.Config()
    .with_rule(@mbtlint.prefer_collection_map())
    .lint(path="sample.mbt", source~)
  assert_eq(findings.map(d => d.rule_id), [Some("prefer-collection-map")])
  assert_true(findings[0].severity == @mbtlint.Error)
  let without_map = @mbtlint.Config()
    .with_collections()
    .without_rule("prefer-collection-map")
  assert_eq(without_map.lint(path="sample.mbt", source~).length(), 0)
}
