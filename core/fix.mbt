///|
/// A half-open UTF-16 range in the exact source passed to lint.
pub struct Edit {
  start : Int32
  end : Int32
  replacement : String
}

///|
pub struct FixResult {
  source : String
  applied : Int32
  diagnostics : Array[Diagnostic]
  rejected : Bool
}

///|
/// Parser locations count Unicode scalars, while String slices use UTF-16.
priv struct LazyOffsets {
  source : String
  mut table : Array[Int32]?
}

///|
fn LazyOffsets::range(
  self : LazyOffsets,
  path : String,
  loc : @basic.Location,
) -> (Int32, Int32)? {
  guard loc.start.fname == path &&
    loc.end.fname == path &&
    loc.start.lnum > 0 &&
    loc.start.cnum >= 0 &&
    loc.start.cnum <= loc.end.cnum else {
    return None
  }
  let table = match self.table {
    Some(table) => table
    None => {
      let table = [0]
      let mut pos = 0
      for ch in self.source {
        pos += if ch.to_int() >= 0x10000 { 2 } else { 1 }
        table.push(pos)
      }
      self.table = Some(table)
      table
    }
  }
  guard loc.end.cnum < table.length() else { return None }
  Some((table[loc.start.cnum], table[loc.end.cnum]))
}

///|
/// Apply one deterministic pass in memory. Reject the whole batch if it breaks parsing.
pub fn Config::fix(
  self : Config,
  path~ : String,
  source~ : String,
) -> FixResult {
  let diagnostics = self.lint(path~, source~)
  let edits : Array[(Int32, Edit)] = []
  for i, d in diagnostics {
    if d.fix is Some(e) && source[e.start:e.end] != e.replacement[:] {
      edits.push((i, e))
    }
  }
  edits.sort_by_key(entry => (entry.1.start, entry.0))
  let out = StringBuilder()
  let mut cursor = 0
  let mut last_start = -1
  let mut applied = 0
  for (_, e) in edits {
    if e.start < cursor || e.start == last_start {
      continue
    }
    out.write_view(source[cursor:e.start])
    out.write_string(e.replacement)
    last_start = e.start
    cursor = e.end
    applied += 1
  }
  if applied == 0 {
    return { source, diagnostics, applied, rejected: false, }
  }
  out.write_view(source[cursor:])
  let updated = out.to_string()
  let remaining = self.lint(path~, source=updated)
  if remaining.any(d => d.rule_id is None) {
    { source, diagnostics, applied: 0, rejected: true, }
  } else {
    { source: updated, diagnostics: remaining, applied, rejected: false, }
  }
}
