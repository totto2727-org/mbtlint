///|
/// Bump the engine revision when changing parse or diagnostic semantics or this
/// cache format. Keep the dependency revisions in sync with moon.mod.
let cache_schema = "mbtlint-engine:1/parser:0.4.9/lexer:0.4.5"

///|
let cache_entry_limit : Int32 = 1024 * 1024

///|
priv struct LintCache {
  dir : @path.Path
  cwd : String
  rules_digest : String
}

///|
type CachedPosition = (String, Int32, Int32, Int32)

///|
#derive(ToJson, FromJson)
priv struct CachedDiagnostic {
  rule_id : String?
  is_error : Bool
  start : CachedPosition
  end : CachedPosition
  message : String
  edit : (Int32, Int32, String)?
}

///|
#derive(ToJson, FromJson)
priv struct CacheEntry {
  slot : String
  source_digest : String
  diagnostics : Array[CachedDiagnostic]
}

///|
fn cache_digest(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn default_cache_dir() -> @path.Path? {
  if @env.get_env_var("XDG_CACHE_HOME") is Some(base) &&
    @path.Path(base).is_absolute() {
    return Some(@path.Path(base).join(@path.Path("mbtlint")))
  }
  if @env.get_env_var("LOCALAPPDATA") is Some(base) &&
    @path.Path(base).is_absolute() {
    return Some(@path.Path(base).join(@path.Path("mbtlint")))
  }
  guard @env.get_env_var("HOME") is Some(home) && @path.Path(home).is_absolute() else {
    return None
  }
  Some(@path.Path(home).join(@path.Path(".cache")).join(@path.Path("mbtlint")))
}

///|
fn LintCache::open(config : Config, override_dir : String?) -> LintCache? {
  let rules : Array[(String, String, Bool)] = []
  for (rule, severity) in config.rules {
    guard rule.revision is Some(revision) else { return None }
    rules.push((rule.id, revision, severity == Error))
  }
  guard @env.current_dir() is Some(cwd) else { return None }
  let directory = match override_dir {
    Some("") => None
    Some(dir) => Some(@path.Path(dir))
    None => default_cache_dir()
  }
  guard directory is Some(dir) else { return None }
  Some({
    dir,
    cwd,
    rules_digest: cache_digest(
      @utf8.encode(@json.to_json((cache_schema, rules)).stringify()),
    ),
  })
}

///|
fn pack_position(pos : @basic.Position) -> CachedPosition {
  (pos.fname, pos.lnum, pos.bol, pos.cnum)
}

///|
fn unpack_position(pos : CachedPosition) -> @basic.Position {
  let (fname, lnum, bol, cnum) = pos
  { fname, lnum, bol, cnum, }
}

///|
fn CachedDiagnostic::pack(d : Diagnostic) -> CachedDiagnostic {
  {
    rule_id: d.rule_id,
    is_error: d.severity == Error,
    start: pack_position(d.loc.start),
    end: pack_position(d.loc.end),
    message: d.message,
    edit: d.fix.map(e => (e.start, e.end, e.replacement)),
  }
}

///|
fn CachedDiagnostic::unpack(
  self : CachedDiagnostic,
  path : String,
) -> Diagnostic {
  {
    path,
    rule_id: self.rule_id,
    severity: if self.is_error {
      Error
    } else {
      Warning
    },
    loc: { start: unpack_position(self.start), end: unpack_position(self.end), },
    message: self.message,
    fix: self.edit.map(e => Edit::{ start: e.0, end: e.1, replacement: e.2, }),
  }
}

///|
fn read_cache_entry(file : String) -> CacheEntry? {
  let bytes = @fs.read_file_to_bytes(file) catch { _ => return None }
  guard bytes.length() <= cache_entry_limit else { return None }
  let text = @utf8.decode(bytes) catch { _ => return None }
  guard text.split_once("\n") is Some((checksum, payload)) else { return None }
  guard checksum == cache_digest(@utf8.encode(payload))[:] else { return None }
  let json = @json.parse(
    payload,
    max_nesting_depth=16,
    reject_duplicate_keys=true,
  ) catch {
    _ => return None
  }
  let entry : CacheEntry = @json.from_json(json) catch { _ => return None }
  Some(entry)
}

///|
fn ensure_cache_dir(dir : @path.Path) -> Unit raise @fs.IOError {
  let name = dir.to_string()
  if @fs.path_exists(name) {
    return
  }
  let parent = dir.dirname()
  if parent != dir {
    ensure_cache_dir(parent)
  }
  @fs.create_dir(name) catch {
    error => if !@fs.path_exists(name) { raise error }
  }
}

///|
fn LintCache::store(
  self : LintCache,
  file : String,
  entry : CacheEntry,
) -> Unit {
  let payload = @json.to_json(entry).stringify()
  let bytes = @utf8.encode(payload)
  guard bytes.length() <= cache_entry_limit - 65 else { return }
  let text = "\{cache_digest(bytes)}\n\{payload}"
  // Concurrent or interrupted writes may create a miss, never a partial hit.
  try {
    ensure_cache_dir(self.dir)
    @fs.write_bytes_to_file(file, @utf8.encode(text))
  } catch {
    _ => ()
  }
}

///|
fn LintCache::lint(
  self : LintCache,
  config : Config,
  path : String,
  source : String,
  bytes : Bytes,
) -> Array[Diagnostic] {
  let slot = cache_digest(
    @utf8.encode(@json.to_json((self.rules_digest, self.cwd, path)).stringify()),
  )
  let source_digest = cache_digest(bytes)
  let file = self.dir.join(@path.Path("\{slot}.json")).to_string()
  if read_cache_entry(file) is Some(entry) &&
    entry.slot == slot &&
    entry.source_digest == source_digest {
    return entry.diagnostics.map(d => d.unpack(path))
  }
  let diagnostics = config.lint(path~, source~)
  self.store(file, {
    slot,
    source_digest,
    diagnostics: diagnostics.map(CachedDiagnostic::pack),
  })
  diagnostics
}
