///|
/// Report `try!`, which turns a raised error into a panic.
pub fn no_try_bang() -> @core.Rule {
  builtin_rule("no-try-bang", ctx => {
    safety_listener(ctx, expr => {
      if expr is TryOperator(kind=Exclamation, try_loc~, ..) {
        Some((try_loc, "Handle or propagate the error instead of using try!."))
      } else {
        None
      }
    })
  })
}
