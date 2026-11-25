///|
fn contract_pure_name(name : String) -> Bool {
  ["compute", "calculate", "derive", "format", "to", "parse"].any(word => {
    contract_prefix(name, word)
  })
}

///|
fn contract_receiver_root(expr : @syntax.Expr) -> String? {
  match expr {
    Ident(id={ name: Ident(name~), .. }, ..) => Some(name)
    Field(record~, ..) => contract_receiver_root(record)
    Group(expr~, ..) => contract_receiver_root(expr)
    _ => None
  }
}

///|
/// Report direct output and parameter field writes in conventionally pure-named functions.
pub fn pure_name_is_pure() -> @core.Rule {
  builtin_rule("pure-name-is-pure", ctx => {
    let file_names = contract_file_names(ctx.program)
    @core.Listener(on_decl=decl => {
      guard decl
        is TopFuncDef(
          fun_decl={ name, decl_params, .. },
          decl_body=DeclBody(expr~),
          ..
        ) &&
        contract_pure_name(name.name) else {
        return
      }
      let params = contract_parameter_names(decl_params)
      let local_names = []
      IterVisitor::visit_Expr(ContractShadows(local_names), expr)
      let shadows = file_names + params + local_names
      IterVisitor::visit_Expr(
        ContractBody(node => {
          if contract_core_call(node, shadows) is Some(("println", loc)) {
            (ctx.report)(
              loc, "This computation-named function prints directly to stdout.",
            )
          }
          if node is Mutate(record~, loc~, ..) &&
            contract_receiver_root(record) is Some(root) &&
            params.contains(root) &&
            !local_names.contains(root) {
            (ctx.report)(
              loc, "This computation-named function writes to a field of a parameter.",
            )
          }
        }),
        expr,
      )
    })
  })
}
