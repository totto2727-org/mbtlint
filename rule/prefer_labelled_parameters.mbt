///|
fn caller_parameters(decl : @syntax.FunDecl) -> @list.List[@syntax.Parameter] {
  guard decl.decl_params is Some(params) else { return @list.List([]) }
  match (decl.type_name, params) {
    (
      Some({ name: Ident(name=owner), .. }),
      More(
        Positional(
          ty=Some(Name(constr_id={ id: Ident(name=receiver), .. }, ..)),
          ..
        ),
        tail~,
      ),
    ) if receiver == owner && decl.name.name != owner => tail
    _ => params
  }
}

///|
/// Require labels when a function or method takes at least four caller-supplied parameters.
pub fn prefer_labelled_parameters() -> @core.Rule {
  builtin_rule("prefer-labelled-parameters", ctx => {
    @core.Listener(on_decl=decl => {
      guard decl is TopFuncDef(fun_decl~, decl_body=DeclBody(..), ..) else {
        return
      }
      let params = caller_parameters(fun_decl)
      if params.length() >= 4 &&
        params.any(param => param is (Positional(..) | DiscardPositional(..))) {
        (ctx.report)(
          fun_decl.name.loc,
          "Give every caller-supplied parameter a label when there are four or more.",
        )
      }
    })
  })
}
