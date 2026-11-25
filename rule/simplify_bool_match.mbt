///|
/// Use the Boolean scrutinee or its negation instead of a two-arm match.
pub fn simplify_bool_match() -> @core.Rule {
  builtin_rule("simplify-bool-match", ctx => {
    @core.Listener(on_expr=expr => {
      guard expr is Match(expr=value, cases~, loc~, ..) &&
        cases is More(first, tail=More(second, tail=Empty)) &&
        first.guard_ is None &&
        second.guard_ is None &&
        first.pattern is Constant(c=Bool(first_input), ..) &&
        second.pattern is Constant(c=Bool(second_input), ..) &&
        first_input != second_input &&
        simplification_bool(first.body) is Some(first_output) &&
        simplification_bool(second.body) is Some(second_output) &&
        first_output != second_output else {
        return
      }
      let negate = first_input != first_output
      let message = if negate {
        "Use the negation of the Boolean scrutinee."
      } else {
        "Use the Boolean scrutinee directly."
      }
      simplification_bool_result(ctx, loc, value, negate, message)
    })
  })
}
