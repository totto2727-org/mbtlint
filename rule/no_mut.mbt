///|
/// Reject explicit `mut` declarations, not all possible mutation through aliases.
pub fn no_mut() -> @core.Rule {
  builtin_rule("no-mut", ctx => {
    fn constructors(items : @list.List[@syntax.ConstrDecl]) {
      for item in items {
        if item.args is Some(args) {
          for arg in args {
            if arg.mut_ {
              let loc = match arg.label {
                Some(label) => label.loc
                None => arg.ty.loc()
              }
              (ctx.report)(loc, "Use an immutable constructor field.")
            }
          }
        }
      }
    }
    @core.Listener(
      on_decl=decl => {
        if decl is TopTypeDef(t) {
          match t.components {
            Record(fields~, ..) =>
              for f in fields {
                if f.mut_ {
                  (ctx.report)(f.name.loc, "Use an immutable record field.")
                }
              }
            Variant(cs)
            | Error(EnumPayload(cs))
            | ExtensibleEnum(Some(cs))
            | ExtendEnum(constructors=cs, ..) => constructors(cs)
            _ => ()
          }
        }
      },
      on_expr=expr => {
        if expr is LetMut(binder~, ..) {
          (ctx.report)(
            binder.loc,
            "Replace `let mut` with an immutable binding or a fold.",
          )
        }
      },
    )
  })
}
