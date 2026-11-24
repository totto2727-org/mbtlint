///|
pub fn no_todo() -> Rule {
  Rule("no-todo", ctx => {
    Listener(on_expr=expr => {
      if expr is Hole(kind=Todo, loc~) {
        (ctx.report)(loc, "Replace the placeholder with an implementation.")
      }
    })
  })
}

///|
pub fn no_duplicate_test_name() -> Rule {
  Rule("no-duplicate-test-name", ctx => {
    let seen : Set[String] = Set([])
    Listener(on_decl=decl => {
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

///|
pub fn Config::recommended() -> Config {
  Config().with_rule(no_todo()).with_rule(no_duplicate_test_name())
}
