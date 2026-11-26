///|
/// Prefer arrow syntax for inline callbacks without an explicit signature.
pub fn prefer_arrow_callback() -> @core.Rule {
  builtin_rule("prefer-arrow-callback", ctx => {
    @core.Listener(on_expr=expr => {
      let args = match expr {
        Apply(args~, ..) | DotApply(args~, ..) => args
        _ => return
      }
      for arg in args {
        if without_parens(arg.value)
          is Function(
            func={
              kind: Lambda,
              parameters,
              return_type: None,
              error_type: NoErrorType,
              is_async: None,
              nocancel_: None,
              ..
            },
            loc~,
          ) &&
          parameters.all(param => {
            param is (Positional(ty=None, ..) | DiscardPositional(ty=None, ..))
          }) {
          (ctx.report)(loc, "Use arrow syntax for this inline callback.")
        }
      }
    })
  })
}
