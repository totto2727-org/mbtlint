///|
/// Report redundant Boolean identity operands without changing short-circuit scopes.
pub fn redundant_bool_operand() -> @core.Rule {
  builtin_rule("redundant-bool-operand", ctx => {
    @core.Listener(on_expr=expr => {
      if expr is Infix(op={ name: Ident(name~), .. }, lhs~, rhs~, loc~) &&
        (name == "&&" || name == "||") {
        let identity = name == "&&"
        let left = simplification_bool(lhs)
        let right = simplification_bool(rhs)
        // Leave pairs of literals to a constant-expression analysis.
        if (left == Some(identity) && right is None) ||
          (left is None && right == Some(identity)) {
          (ctx.report)(
            loc, "This Boolean operation has a redundant literal operand.",
          )
        }
      }
    })
  })
}
