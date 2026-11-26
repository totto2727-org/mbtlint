///|
fn safety_listener(
  ctx : @core.Context,
  check : (@syntax.Expr) -> (@basic.Location, String)?,
) -> @core.Listener {
  let mut expects_panic = false
  @core.Listener(
    on_decl=decl => {
      expects_panic = match decl {
        TopTest(name=Some((name, _)), ..) =>
          name == "panic" ||
          name.has_prefix("panic ") ||
          name.has_prefix("panic_")
        _ => false
      }
    },
    on_expr=expr => {
      if !expects_panic && check(expr) is Some((loc, message)) {
        (ctx.report)(loc, message)
      }
    },
  )
}

///|
fn safety_ungroup(expr : @syntax.Expr) -> @syntax.Expr {
  match expr {
    Group(expr~, ..) => safety_ungroup(expr)
    _ => expr
  }
}

///|
fn safety_callee(expr : @syntax.Expr) -> @syntax.Expr? {
  match expr {
    Apply(func~, ..) => Some(safety_ungroup(func))
    Pipe(rhs=callee, ..) | RevPipe(lhs=callee, ..) =>
      match safety_ungroup(callee) {
        // Applied pipe targets are already visited as calls.
        Ident(_) | Method(_) as callee => Some(callee)
        _ => None
      }
    _ => None
  }
}

///|
fn safety_core_owner(name : @syntax.LongIdent) -> String? {
  match name {
    Ident(name~) | Dot(pkg="builtin" | "prelude", id=name) => Some(name)
    Dot(pkg="list", id="List") => Some("List")
    Dot(pkg="string", id="Regex") => Some("Regex")
    Dot(pkg="array", id="View") => Some("ArrayView")
    Dot(pkg="bytes", id="View") => Some("BytesView")
    Dot(pkg="string", id="View") => Some("StringView")
    _ => None
  }
}
