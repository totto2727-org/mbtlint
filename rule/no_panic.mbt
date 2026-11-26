///|
fn safety_declares_value(
  program : @list.List[@syntax.Impl],
  name : String,
) -> Bool {
  for decl in program {
    match decl {
      TopFuncDef(fun_decl={ type_name: None, name: binder, .. }, ..)
      | TopLetDef(binder~, ..) => if binder.name == name { return true }
      _ => ()
    }
  }
  false
}

///|
/// Report explicit calls to the core abort and panic functions.
pub fn no_panic() -> @core.Rule {
  builtin_rule("no-panic", ctx => {
    let shadows_abort = safety_declares_value(ctx.program, "abort")
    let shadows_panic = safety_declares_value(ctx.program, "panic")
    safety_listener(ctx, expr => {
      guard safety_callee(expr) is Some(Ident(id={ name, loc, }, ..)) else {
        None
      }
      let unsafe_call = match name {
        Ident(name="abort") => !shadows_abort
        Ident(name="panic") => !shadows_panic
        Dot(pkg="builtin" | "prelude", id="abort" | "panic")
        | Dot(pkg="abort", id="abort") => true
        _ => false
      }
      if unsafe_call {
        Some((loc, "Return or raise a recoverable error instead of panicking."))
      } else {
        None
      }
    })
  })
}
