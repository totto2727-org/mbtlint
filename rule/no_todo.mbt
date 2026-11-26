///|
pub fn no_todo() -> @core.Rule {
  builtin_rule("no-todo", ctx => {
    @core.Listener(on_expr=expr => {
      if expr is Hole(kind=Todo, loc~) {
        (ctx.report)(loc, "Replace the placeholder with an implementation.")
      }
    })
  })
}
