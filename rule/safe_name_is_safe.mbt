///|
fn contract_safe_name(name : String) -> Bool {
  contract_prefix(name, "safe") ||
  contract_prefix(name, "try") ||
  name.has_suffix("_or_default") ||
  name.has_suffix("_or_none") ||
  name.has_suffix("_or_else")
}

///|
/// Report direct core abort or panic calls in conventionally safe-named functions.
pub fn safe_name_is_safe() -> @core.Rule {
  builtin_rule("safe-name-is-safe", ctx => {
    let file_names = contract_file_names(ctx.program)
    @core.Listener(on_decl=decl => {
      guard decl
        is TopFuncDef(
          fun_decl={ name, decl_params, .. },
          decl_body=DeclBody(expr~),
          ..
        ) &&
        contract_safe_name(name.name) else {
        return
      }
      let local_names = contract_parameter_names(decl_params)
      IterVisitor::visit_Expr(ContractShadows(local_names), expr)
      let shadows = file_names + local_names
      IterVisitor::visit_Expr(
        ContractBody(node => {
          if contract_core_call(node, shadows) is Some(("abort" | "panic", loc)) {
            (ctx.report)(
              loc, "This safe-named function calls a core panic operation directly.",
            )
          }
        }),
        expr,
      )
    })
  })
}
