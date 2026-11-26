///|
/// Prefer `label~` or `label?` when the argument is the unqualified name of its label.
pub fn prefer_label_pun() -> @core.Rule {
  builtin_rule("prefer-label-pun", ctx => {
    @core.Listener(on_expr=expr => {
      let args = match expr {
        Apply(args~, ..) | DotApply(args~, ..) => args
        _ => return
      }
      for arg in args {
        let (label, separator, suffix) = match arg.kind {
          Labelled(label) => (label, "=", "~")
          LabelledOption(label~, ..) => (label, "?=", "?")
          _ => continue
        }
        if arg.value is Ident(id={ name: Ident(name~), .. }, loc~) &&
          name == label.name {
          report_pun(
            ctx,
            { start: label.loc.start, end: loc.end, },
            name + separator + name,
            name + suffix,
          )
        }
      }
    })
  })
}
