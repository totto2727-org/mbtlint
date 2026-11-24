///|
/// The host decides how lint failures map to a process exit code.
pub(all) suberror LintFailed {
  LintFailed(Int32)
}

///|
/// Return an Admiral app, not a new command-line runner.
/// Override the default user cache directory with `cache_dir`.
pub fn engine(
  config : Config,
  emit~ : (Diagnostic) -> Unit = d => println(d),
  cache_dir? : String,
) -> @admiral.CliApp {
  let files = @admiral.position_strings(
    "files",
    required=true,
    description="MoonBit source files (.mbt or .mbtx)",
  )
  let fix = @admiral.bool("fix", description="Apply one pass of non-overlapping fixes to the named files")
  let no_cache = @admiral.bool("no-cache", description="Do not read or write the lint result cache")
  @admiral.CliApp(
    name="lint",
    description="Lint MoonBit source files",
    options=[fix, no_cache],
    positionals=[files],
    run=Some(ctx => {
      let mut errors = 0
      let write = ctx.get_bool(fix)
      let cache = if write || ctx.get_bool(no_cache) { None } else { LintCache::open(config, cache_dir) }
      for path in ctx.get_strings_required(files).all {
        guard path.has_suffix(".mbt") || path.has_suffix(".mbtx") else { fail("Expected a .mbt or .mbtx source file: \{path}") }
        let bytes = @fs.read_file_to_bytes(path) catch {
          IOError(reason) => fail("Cannot read \{path}: \{reason}")
        }
        let source = @utf8.decode(bytes) catch { _ => fail("Invalid UTF-8: \{path}") }
        let diagnostics = if write {
          let result = config.fix(path~, source~)
          if result.rejected { fail("Refusing to write \{path}: a rule produced invalid syntax") }
          if result.source != source {
            if @fs.read_file_to_bytes(path) != bytes { fail("Refusing to overwrite changed file: \{path}") }
            @fs.write_bytes_to_file(path, @utf8.encode(result.source)) catch { IOError(reason) => fail("Cannot write \{path}: \{reason}") }
          }
          result.diagnostics
        } else if cache is Some(cache) {
          cache.lint(config, path, source, bytes)
        } else {
          config.lint(path~, source~)
        }
        for d in diagnostics {
          emit(d)
          if d.severity == Error {
            errors += 1
          }
        }
      }
      if errors > 0 {
        raise LintFailed(errors)
      }
    }),
  )
}
