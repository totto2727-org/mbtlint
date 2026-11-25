///|
fn builtin_rule(
  id : String,
  create : (@core.Context) -> @core.Listener,
) -> @core.Rule {
  @core.Rule(id, create, revision="mbtlint/0.1.0:1")
}
