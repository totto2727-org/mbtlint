///|
fn static_contract_findings(
  rule : @mbtlint.Rule,
  source : String,
) -> Array[(String?, Int32, Int32)] {
  @mbtlint.Config()
  .with_rule(rule)
  .lint(path="sample.mbt", source~)
  .map(finding => {
    (finding.rule_id, finding.loc.start.lnum, finding.loc.start.column())
  })
}

///|
test "static contracts: wildcard catches with literal fallbacks" {
  let source =
    #|fn load() -> String {
    #|  try read() catch {
    #|    MissingFile(_) => "missing"
    #|    _ => ""
    #|  }
    #|}
    #|fn count() -> Int {
    #|  let value = try read() catch { _ => "" }
    #|  value.length()
    #|}
    #|fn publish() -> Unit {
    #|  try send() catch { _ => () }
    #|}
  assert_eq(static_contract_findings(@mbtlint.catch_hides_failure(), source), [
    (Some("catch-hides-failure"), 4, 5),
    (Some("catch-hides-failure"), 8, 34),
    (Some("catch-hides-failure"), 12, 22),
  ])
}

///|
test "static contracts: catches leave propagation and declared fallback alone" {
  let source =
    #|fn read_config_or_default() -> String { try read() catch { _ => "" } }
    #|fn try_read() -> String { try read() catch { _ => "" } }
    #|fn read_optional() -> String? { try Some(read()) catch { _ => None } }
    #|fn read_result() -> Result[String, Error] { try Ok(read()) catch { e => Err(e) } }
    #|fn is_readable() -> Bool { try { ignore(read()); true } catch { _ => false } }
    #|fn translate() -> String raise { try read() catch { _ => raise Missing } }
    #|fn guarded(ok : Bool) -> String raise { try read() catch { _ if ok => "" } }
    #|fn retry() -> String { try read() catch { _ => next() } }
    #|fn read_later() -> String {
    #|  let load = () => try read() catch { _ => "" }
    #|  load()
    #|}
    #|fn inspect_error() -> String { try read() catch { e => e.to_string() } }
  assert_eq(static_contract_findings(@mbtlint.catch_hides_failure(), source), [])
}

///|
test "static contracts: direct panic calls use the exact safe name convention" {
  let source =
    #|fn try_fetch(ok : Bool) -> Int { if ok { 1 } else { abort("bad") } }
    #|fn Queue::next_or_none(self : Queue) -> Int? { @builtin.panic() }
    #|fn safe() -> Int { "bad" |> abort }
    #|fn unsafe_fetch() -> Int { panic() }
    #|fn safely_fetch() -> Int { panic() }
    #|fn fetch_or_other() -> Int { panic() }
    #|fn try_parse() -> Int raise { raise InvalidInput }
  assert_eq(static_contract_findings(@mbtlint.safe_name_is_safe(), source), [
    (Some("safe-name-is-safe"), 1, 53),
    (Some("safe-name-is-safe"), 2, 48),
    (Some("safe-name-is-safe"), 3, 29),
  ])
}

///|
test "static contracts: safe name ignores shadowed, indirect and deferred panic calls" {
  let source =
    #|fn panic() -> Int { 42 }
    #|fn safe_file_shadow() -> Int { panic() }
    #|fn safe_arg_shadow(abort : (String) -> Int) -> Int { abort("text") }
    #|fn safe_local_shadow() -> Int {
    #|  let abort = (_ : String) => 1
    #|  abort("text")
    #|}
    #|fn try_service() -> Int { @service.abort("text") }
    #|fn try_later() -> () -> Int {
    #|  fn run() -> Int { @builtin.panic() }
    #|  run
    #|}
    #|fn try_lambda() -> () -> Int { () => @builtin.panic() }
    #|fn try_partial() -> (String) -> Int { @builtin.abort(_) }
    #|fn try_ok(v : Int) -> Int? { if v == 0 { None } else { Some(v) } }
  assert_eq(static_contract_findings(@mbtlint.safe_name_is_safe(), source), [])
}

///|
test "static contracts: computation reports direct stdout and parameter field writes" {
  let source =
    #|fn compute_total(value : Int) -> Int {
    #|  println(value)
    #|  value
    #|}
    #|fn Catalog::derive_revision(self : Catalog) -> Int {
    #|  self.revision += 1
    #|  self.revision
    #|}
    #|fn calculate_nested(catalog : Catalog) -> Unit {
    #|  catalog.stats.revision = 5
    #|}
    #|fn parse_ping() -> Unit { "x" |> @prelude.println }
  assert_eq(static_contract_findings(@mbtlint.pure_name_is_pure(), source), [
    (Some("pure-name-is-pure"), 2, 3),
    (Some("pure-name-is-pure"), 6, 3),
    (Some("pure-name-is-pure"), 10, 3),
    (Some("pure-name-is-pure"), 12, 34),
  ])
}

///|
test "static contracts: computation does not assume effects from local writes or method names" {
  let source =
    #|fn format_total(input : Counter) -> Int { input.value }
    #|fn compute_local(input : Int) -> Int {
    #|  let counter = Counter::{ value: input }
    #|  counter.value += 1
    #|  counter.value
    #|}
    #|fn derive_local(input : Counter) -> Int {
    #|  let input = Counter::{ value: input.value }
    #|  input.value += 1
    #|  input.value
    #|}
    #|fn compute_lambda() -> () -> Unit { () => @builtin.println("deferred") }
    #|fn format_partial() -> (String) -> Unit { @prelude.println(_) }
    #|fn compute_arg(println : (Int) -> Unit) -> Unit { println(1) }
    #|fn parse_methods(input : Counter) -> Unit { input.println() }
    #|fn compute_service() -> Unit { @service.println("unresolved") }
    #|fn compute_abort() -> Unit { abort("not an external write") }
    #|fn reformat() -> Unit { println("not a convention name") }
  assert_eq(static_contract_findings(@mbtlint.pure_name_is_pure(), source), [])
}

///|
test "static contracts: disabled by default, warning configurable and pack has no edits" {
  let source =
    #|fn read_config() -> String { try read() catch { _ => "" } }
    #|fn try_read_config() -> String { abort("cannot read") }
    #|fn parse_config(value : String) -> String { println(value); value }
  let base = @mbtlint.Config()
  assert_eq(base.lint(path="sample.mbt", source~).length(), 0)
  let recommended = @mbtlint.Config::recommended().lint(
    path="sample.mbt",
    source~,
  )
  assert_false(
    recommended.any(d => {
      d.rule_id
      is Some("catch-hides-failure" | "safe-name-is-safe" | "pure-name-is-pure")
    }),
  )
  let findings = base
    .with_static_contracts()
    .with_rule(@mbtlint.safe_name_is_safe(), severity=Warning)
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
