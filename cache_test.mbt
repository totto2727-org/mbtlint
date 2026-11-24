///|
fn new_cache_fixture() -> String raise {
  let nonce = @env.rand(16).unwrap()
  let dir = "tmp/mbtlint-cache-test-" + @crypto.bytes_to_hex_string(nonce)
  if !@fs.path_exists("tmp") {
    @fs.create_dir("tmp") catch {
      error => if !@fs.path_exists("tmp") { raise error }
    }
  }
  @fs.create_dir(dir)
  dir
}

///|
fn remove_cache_fixture(dir : String) -> Unit {
  let children = @fs.read_dir(dir) catch { _ => return }
  for child in children {
    let path = "\{dir}/\{child}"
    if (@fs.is_dir(path) catch { _ => false }) {
      remove_cache_fixture(path)
    } else {
      @fs.remove_file(path) catch {
        _ => ()
      }
    }
  }
  @fs.remove_dir(dir) catch {
    _ => ()
  }
}

///|
fn observe_one(
  id : String,
  calls : Ref[Int32],
  revision? : String,
) -> @mbtlint.Rule {
  @mbtlint.Rule(id, revision?, ctx => {
    calls.val += 1
    @mbtlint.Listener(on_expr=expr => {
      if expr is Constant(c=Int("1"), loc~) {
        (ctx.report_fix)(loc, "Replace the number 🌙\nSecond line", "2")
      }
    })
  })
}

///|
async fn run_cache_cli(
  config : @mbtlint.Config,
  cache_dir : String,
  args : Array[String],
) -> (Array[@mbtlint.Diagnostic], Int32) {
  let diagnostics = []
  let app = @mbtlint.engine(config, cache_dir~, emit=d => diagnostics.push(d))
  let errors = try {
    app.run(argv=Some(args))
    0
  } catch {
    @mbtlint.LintFailed(errors) => errors
    other => raise other
  }
  (diagnostics, errors)
}

///|
fn assert_diagnostics_equal(
  expected : Array[@mbtlint.Diagnostic],
  actual : Array[@mbtlint.Diagnostic],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i, d in expected {
    let other = actual[i]
    assert_eq(other.path, d.path)
    assert_eq(other.rule_id, d.rule_id)
    assert_true(other.severity == d.severity)
    assert_eq(@json.to_json(other.loc.start), @json.to_json(d.loc.start))
    assert_eq(@json.to_json(other.loc.end), @json.to_json(d.loc.end))
    assert_eq(other.message, d.message)
    assert_eq(
      other.fix.map(e => (e.start, e.end, e.replacement)),
      d.fix.map(e => (e.start, e.end, e.replacement)),
    )
  }
}

///|
async test "warm cache reproduces diagnostics, edits and CLI error count" {
  let root = new_cache_fixture()
  defer remove_cache_fixture(root)
  let file = "\{root}/source.mbtx"
  let dir = "\{root}/nested/cache"
  let source = "---\n// 🌙\n---\n// 🛰️\nlet a = 1\nlet b = 1\n"
  @fs.write_string_to_file(file, source)
  let calls = Ref(0)
  let error = observe_one("error", calls, revision="1")
  let warning = observe_one("warning", calls, revision="1")
  let config = @mbtlint.Config()
    .with_rule(error)
    .with_rule(warning, severity=Warning)
  let (cold, cold_errors) = run_cache_cli(config, dir, [file])
  assert_eq(calls.val, 2)
  assert_eq(cold.length(), 4)
  assert_eq(cold_errors, 2)
  assert_eq(@fs.read_dir(dir).length(), 1)
  let (warm, warm_errors) = run_cache_cli(config, dir, [file])
  assert_eq(calls.val, 2)
  assert_eq(warm_errors, cold_errors)
  assert_diagnostics_equal(cold, warm)

  let invalid = "\{root}/invalid.mbt"
  @fs.write_string_to_file(invalid, "let x = (\n")
  let (first, first_errors) = run_cache_cli(config, dir, [invalid])
  let (second, second_errors) = run_cache_cli(config, dir, [invalid])
  assert_true(first_errors > 0)
  assert_eq(second_errors, first_errors)
  assert_true(first.all(d => d.rule_id is None && d.fix is None))
  assert_diagnostics_equal(first, second)
}

///|
async test "cache tracks bytes, file spelling, ordered rule IDs, revisions and severity" {
  let root = new_cache_fixture()
  defer remove_cache_fixture(root)
  let path = "\{root}/source.mbt"
  let cache = "\{root}/cache"
  @fs.write_string_to_file(path, "let a = 1\n")
  let calls = Ref(0)
  let a = observe_one("first", calls, revision="1")
  let b = observe_one("second", calls, revision="1")
  let config = @mbtlint.Config().with_rule(a).with_rule(b)
  ignore(run_cache_cli(config, cache, [path]))
  ignore(run_cache_cli(config, cache, [path]))
  assert_eq(calls.val, 2)

  @fs.write_string_to_file(path, "let a = 0\n")
  let (changed, _) = run_cache_cli(config, cache, [path])
  assert_true(changed.is_empty())
  assert_eq(calls.val, 4)
  assert_eq(@fs.read_dir(cache).length(), 1)
  @fs.write_string_to_file(path, "let a = 1\n")
  ignore(run_cache_cli(config, cache, [path]))
  assert_eq(calls.val, 6)
  let alternate_path = "\{root}/./source.mbt"
  let (alias_diagnostics, _) = run_cache_cli(config, cache, [alternate_path])
  assert_true(alias_diagnostics.all(d => d.path == alternate_path))
  assert_eq(calls.val, 8)

  let swapped = @mbtlint.Config().with_rule(b).with_rule(a)
  let (reordered, _) = run_cache_cli(swapped, cache, [path])
  assert_eq(reordered.map(d => d.rule_id), [Some("second"), Some("first")])
  assert_eq(calls.val, 10)
  let renamed = @mbtlint.Config()
    .with_rule(observe_one("renamed", calls, revision="1"))
    .with_rule(b)
  ignore(run_cache_cli(renamed, cache, [path]))
  assert_eq(calls.val, 12)
  let revised = @mbtlint.Config()
    .with_rule(observe_one("first", calls, revision="2"))
    .with_rule(b)
  ignore(run_cache_cli(revised, cache, [path]))
  assert_eq(calls.val, 14)
  let severity_changed = @mbtlint.Config()
    .with_rule(a, severity=Warning)
    .with_rule(b)
  let (_, errors) = run_cache_cli(severity_changed, cache, [path])
  assert_eq(errors, 1)
  assert_eq(calls.val, 16)
}

///|
async test "corruption, wrong slots, and unavailable storage fall back to lint" {
  let root = new_cache_fixture()
  defer remove_cache_fixture(root)
  let path = "\{root}/source.mbt"
  let second = "\{root}/other.mbt"
  let cache = "\{root}/cache"
  let source = "let a = 1\n"
  @fs.write_string_to_file(path, source)
  @fs.write_string_to_file(second, source)
  let calls = Ref(0)
  let config = @mbtlint.Config().with_rule(
    observe_one("one", calls, revision="1"),
  )
  let (cold, _) = run_cache_cli(config, cache, [path])
  let slot_name = @fs.read_dir(cache)[0]
  let slot = "\{cache}/\{slot_name}"
  @fs.write_string_to_file(slot, "{\"diagnostics\":[]}")
  let (recovered, _) = run_cache_cli(config, cache, [path])
  assert_eq(calls.val, 2)
  assert_diagnostics_equal(cold, recovered)
  let malformed = "{not valid JSON}"
  let checksum = @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(malformed)),
  )
  @fs.write_string_to_file(slot, "\{checksum}\n\{malformed}")
  let (malformed_recovered, _) = run_cache_cli(config, cache, [path])
  assert_eq(calls.val, 3)
  assert_diagnostics_equal(cold, malformed_recovered)
  ignore(run_cache_cli(config, cache, [second]))
  let other_name = @fs.read_dir(cache)
    .iter()
    .filter(name => name != slot_name)
    .next()
    .unwrap()
  @fs.write_bytes_to_file(
    slot,
    @fs.read_file_to_bytes("\{cache}/\{other_name}"),
  )
  let (correct_slot, _) = run_cache_cli(config, cache, [path])
  assert_eq(calls.val, 5)
  assert_diagnostics_equal(cold, correct_slot)
  let (no_storage, _) = run_cache_cli(config, "\{path}/cache", [path])
  assert_eq(calls.val, 6)
  assert_diagnostics_equal(cold, no_storage)
}

///|
async test "disabled, unversioned, and fix runs bypass cache reads and writes" {
  let root = new_cache_fixture()
  defer remove_cache_fixture(root)
  let path = "\{root}/source.mbt"
  let cache = "\{root}/cache"
  let unused = "\{root}/unused"
  let source = "let a = 1\n"
  @fs.write_string_to_file(path, source)
  let calls = Ref(0)
  let config = @mbtlint.Config().with_rule(
    observe_one("one", calls, revision="1"),
  )
  ignore(run_cache_cli(config, unused, ["--no-cache", path]))
  assert_false(@fs.path_exists(unused))
  ignore(run_cache_cli(config, cache, [path]))
  assert_eq(calls.val, 2)
  let slot = "\{cache}/\{@fs.read_dir(cache)[0]}"
  let original_entry = @fs.read_file_to_bytes(slot)
  ignore(run_cache_cli(config, cache, ["--no-cache", path]))
  assert_eq(calls.val, 3)
  assert_eq(@fs.read_file_to_bytes(slot), original_entry)

  let unversioned = config.with_rule(observe_one("unversioned", calls))
  let (diagnostics, _) = run_cache_cli(unversioned, unused, [path])
  assert_eq(calls.val, 5)
  assert_eq(diagnostics.length(), 2)
  assert_false(@fs.path_exists(unused))

  let (fixed, errors) = run_cache_cli(config, cache, ["--fix", path])
  assert_eq(calls.val, 7)
  assert_eq(errors, 0)
  assert_true(fixed.is_empty())
  assert_eq(@fs.read_file_to_string(path), "let a = 2\n")
  assert_eq(@fs.read_dir(cache).length(), 1)
  assert_eq(@fs.read_file_to_bytes(slot), original_entry)

  let invalid_utf8 = b"\xff"
  @fs.write_bytes_to_file(path, invalid_utf8)
  let rejected = try {
    ignore(run_cache_cli(config, cache, [path]))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(@fs.read_file_to_bytes(path), invalid_utf8)
  assert_eq(@fs.read_file_to_bytes(slot), original_entry)
  assert_eq(calls.val, 7)
}
