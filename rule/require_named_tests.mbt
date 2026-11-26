///|
/// Require a nonblank name on each test block.
pub fn require_named_tests() -> @core.Rule {
  builtin_rule("require-named-tests", ctx => {
    @core.Listener(on_decl=decl => {
      guard decl is TopTest(name~, loc~, ..) else { return }
      match name {
        None => (ctx.report)(loc, "Name this test to describe the scenario.")
        Some((title, title_loc)) if title.trim().is_empty() =>
          (ctx.report)(title_loc, "Give this test a nonblank name.")
        Some(_) => ()
      }
    })
  })
}
