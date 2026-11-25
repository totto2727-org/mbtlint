///|
/// Use the condition or its negation instead of opposite Boolean branches.
pub fn simplify_bool_if() -> @core.Rule {
  builtin_rule("simplify-bool-if", ctx => {
    let else_if_starts : Set[Int32] = Set([])
    @core.Listener(on_expr=expr => {
      guard expr is If(cond~, ifso~, ifnot=Some(otherwise), loc~) else {
        return
      }
      if otherwise is If(loc=child, ..) {
        else_if_starts.add(child.start.cnum)
      }
      if simplification_bool(cond) is None &&
        simplification_bool(ifso) is Some(yes) &&
        simplification_bool(otherwise) is Some(no) &&
        yes != no {
        let message = if yes {
          "Use the Boolean condition directly."
        } else {
          "Use the negation of the Boolean condition."
        }
        // A bare expression cannot replace the `if` directly following `else`.
        simplification_bool_result(
          ctx,
          loc,
          cond,
          !yes,
          message,
          allow_fix=!else_if_starts.contains(loc.start.cnum),
        )
      }
    })
  })
}
