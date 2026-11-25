///|
pub fn no_duplicate_test_name() -> @core.Rule {
  builtin_rule("no-duplicate-test-name", ctx => {
    let seen : Set[String] = Set([])
    @core.Listener(on_decl=decl => {
      if decl is TopTest(name=Some((name, loc)), ..) {
        if seen.contains(name) {
          (ctx.report)(loc, "Duplicate test name: \{name}")
        } else {
          seen.add(name)
        }
      }
    })
  })
}
