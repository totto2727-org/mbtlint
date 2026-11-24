///|
/// The host decides how lint failures map to a process exit code.
pub(all) suberror LintFailed {
  LintFailed(Int32)
}

///|
/// Return an Admiral app, not a new command-line runner.
pub fn engine(
  config : Config,
  emit~ : (Diagnostic) -> Unit = d => println(d),
) -> @admiral.CliApp {
  let files = @admiral.position_strings(
    "files",
    required=true,
    description="MoonBit source files (.mbt or .mbtx)",
  )
  @admiral.CliApp(
    name="lint",
    description="Lint MoonBit source files",
    positionals=[files],
    run=Some(ctx => {
      let mut errors = 0
      for path in ctx.get_strings_required(files).all {
        let source = @fs.read_file_to_string(path) catch {
          IOError(reason) => fail("Cannot read \{path}: \{reason}")
        }
        for d in config.lint(path~, source~) {
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
