///|
fn contract_literal_fallback(expr : @syntax.Expr) -> Bool {
  match expr {
    Group(expr~, ..) => contract_literal_fallback(expr)
    Return(return_value=Some(expr), ..) => contract_literal_fallback(expr)
    Return(return_value=None, ..) | Unit(..) => true
    Constant(c=String(_) | Int(_) | UInt(_) | Int64(_) | UInt64(_), ..) => true
    Array(exprs~, is_iter=false, ..) => exprs.is_empty()
    _ => false
  }
}

///|
/// Report wildcard catches with a literal fallback in explicitly plain-returning functions.
pub fn catch_hides_failure() -> @core.Rule {
  builtin_rule("catch-hides-failure", ctx => {
    @core.Listener(on_decl=decl => {
      guard decl
        is TopFuncDef(
          fun_decl={ name, return_type, .. },
          decl_body=DeclBody(expr~),
          ..
        ) else {
        return
      }
      let name = name.name
      guard !["safe", "try", "maybe"].any(word => contract_prefix(name, word)) &&
        !["_or_null", "_or_default", "_or_else", "_or_none", "_or"].any(suffix => {
          name.has_suffix(suffix)
        }) else {
        return
      }
      guard return_type
        is Some(
          Name(
            constr_id={
              id: Ident(
                name="String"
                | "Int"
                | "Int64"
                | "UInt"
                | "UInt64"
                | "Unit"
                | "Array",
              ),
              ..
            },
            ..
          ),
        ) else {
        return
      }
      IterVisitor::visit_Expr(
        ContractBody(node => {
          if node is Try(catch_~, ..) {
            for case in catch_ {
              if case is { pattern: Any(loc~), guard_: None, body, } &&
                contract_literal_fallback(body) {
                (ctx.report)(
                  loc, "This wildcard catch discards the error and substitutes a literal fallback.",
                )
              }
            }
          }
        }),
        expr,
      )
    })
  })
}
