///|
fn without_expression_groups(expr : @syntax.Expr) -> @syntax.Expr {
  match expr {
    Group(expr~, ..) => without_expression_groups(expr)
    _ => expr
  }
}

///|
/// Prefer direct error propagation over catching and immediately raising the same error.
pub fn no_redundant_rethrow() -> @core.Rule {
  builtin_rule("no-redundant-rethrow", ctx => {
    @core.Listener(on_expr=expr => {
      guard expr is Try(catch_~, try_else=None, catch_loc~, ..) &&
        catch_
        is More({ pattern: Var({ name, .. }), guard_: None, body, }, tail=Empty) &&
        without_expression_groups(body) is Raise(err_value~, ..) &&
        without_parens(err_value)
        is Ident(id={ name: Ident(name=raised), .. }, ..) &&
        name == raised else {
        return
      }
      (ctx.report)(
        catch_loc, "Remove this catch and let the original error propagate.",
      )
    })
  })
}
