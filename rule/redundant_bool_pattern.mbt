///|
/// Test a Boolean directly instead of matching a Boolean literal with `is`.
pub fn redundant_bool_pattern() -> @core.Rule {
  builtin_rule("redundant-bool-pattern", ctx => {
    @core.Listener(on_expr=expr => {
      if expr is Is(expr=value, pat=Constant(c=Bool(expected), ..), loc~) {
        let message = if expected {
          "Use the Boolean expression directly instead of `is true`."
        } else {
          "Negate the Boolean expression instead of matching `is false`."
        }
        simplification_bool_result(ctx, loc, value, !expected, message)
      }
    })
  })
}
