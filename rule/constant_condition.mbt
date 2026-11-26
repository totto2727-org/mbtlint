///|
/// Report literal `if`, `guard`, and explicit C-style `for` conditions, and `while false`.
pub fn constant_condition() -> @core.Rule {
  builtin_rule("constant-condition", ctx => {
    @core.Listener(on_expr=expr => {
      match expr {
        If(cond~, ..) | Guard(cond~, ..) | For(condition=Some(cond), ..) =>
          if simplification_bool(cond) is Some(value) {
            (ctx.report)(cond.loc(), "This condition is always \{value}.")
          }
        While(loop_cond~, ..) =>
          if simplification_bool(loop_cond) is Some(false) {
            (ctx.report)(
              loop_cond.loc(),
              "This loop condition is always false.",
            )
          }
        _ => ()
      }
    })
  })
}
