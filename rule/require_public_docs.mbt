///|
/// Require a nonempty documentation comment on exported declarations.
pub fn require_public_docs() -> @core.Rule {
  builtin_rule("require-public-docs", ctx => {
    @core.Listener(on_decl=decl => {
      let (vis, doc, loc) = match decl {
        TopFuncDef(fun_decl=f, ..) => (f.vis, f.doc, f.name.loc)
        TopTypeDef(t) => (t.type_vis, t.doc, t.tycon_loc)
        TopTrait(t) => (t.vis, t.doc, t.name.loc)
        TopLetDef(binder~, vis~, doc~, ..) => (vis, doc, binder.loc)
        _ => return
      }
      if vis is Pub(..) && doc.content.all(line => line.trim().is_empty()) {
        (ctx.report)(loc, "Document this public declaration with `///`.")
      }
    })
  })
}
