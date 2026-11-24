///|
fn report_pun(ctx : Context, loc : @basic.Location, expected : String, replacement : String) -> Unit {
  let message = "Use the shorthand `\{replacement}`."
  if ctx.text(loc) is Some(text) {
    let tokens = StringBuilder()
    for c in text {
      if c != ' ' && c != '\t' && c != '\r' && c != '\n' { tokens.write_char(c) }
    }
    if tokens.to_string() == expected {
      (ctx.report_fix)(loc, message, replacement)
      return
    }
  }
  (ctx.report)(loc, message)
}

///|
/// Prefer `label~` or `label?` when the argument is the unqualified name of its label.
pub fn prefer_label_pun() -> Rule {
  builtin_rule("prefer-label-pun", ctx => Listener(on_expr=expr => {
    let args = match expr { Apply(args~, ..) | DotApply(args~, ..) => args; _ => return }
    for arg in args {
      let (label, separator, suffix) = match arg.kind {
        Labelled(label) => (label, "=", "~")
        LabelledOption(label~, ..) => (label, "?=", "?")
        _ => continue
      }
      if arg.value is Ident(id={ name: Ident(name~), .. }, loc~) && name == label.name {
        report_pun(ctx, { start: label.loc.start, end: loc.end }, name + separator + name, name + suffix)
      }
    }
  }))
}

///|
/// Prefer `{ name, }` to `{ name: name }`. Keep a lone untyped record distinct from a block.
pub fn prefer_field_pun() -> Rule {
  builtin_rule("prefer-field-pun", ctx => Listener(on_expr=expr => {
    let (fields, comma) = match expr {
      Record(fields~, type_name~, trailing~, ..) => (fields, type_name is None && trailing is None && fields is More(_, tail=Empty))
      RecordUpdate(fields~, ..) => (fields, false)
      _ => return
    }
    for field in fields {
      if !field.is_pun && field.expr is Ident(id={ name: Ident(name~), .. }, loc~) && field.label.name == name {
        report_pun(ctx, { start: field.label.loc.start, end: loc.end }, name + ":" + name, if comma { name + "," } else { name })
      }
    }
  }))
}
