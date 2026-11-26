///|
/// Report exact, unqualified variable self-assignment, not field or index writes.
pub fn no_self_assignment() -> @core.Rule {
  builtin_rule("no-self-assignment", ctx => {
    @core.Listener(on_expr=expr => {
      if expr
        is Assign(
          var_={ name: Ident(name=target), .. },
          expr=value,
          augmented_by=None,
          loc~,
        ) &&
        simplification_ungroup(value)
        is Ident(id={ name: Ident(name=source), .. }, ..) &&
        target == source {
        (ctx.report)(
          loc, "This assignment writes the variable's current value back to itself.",
        )
      }
    })
  })
}
