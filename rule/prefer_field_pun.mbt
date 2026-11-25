///|
/// Prefer `{ name, }` to `{ name: name }`. Keep a lone untyped record distinct from a block.
pub fn prefer_field_pun() -> @core.Rule {
  builtin_rule("prefer-field-pun", ctx => {
    @core.Listener(on_expr=expr => {
      let (fields, comma) = match expr {
        Record(fields~, type_name~, trailing~, ..) =>
          (
            fields,
            type_name is None &&
            trailing is None &&
            fields is More(_, tail=Empty),
          )
        RecordUpdate(fields~, ..) => (fields, false)
        _ => return
      }
      for field in fields {
        if !field.is_pun &&
          field.expr is Ident(id={ name: Ident(name~), .. }, loc~) &&
          field.label.name == name {
          report_pun(
            ctx,
            { start: field.label.loc.start, end: loc.end, },
            name + ":" + name,
            if comma {
              name + ","
            } else {
              name
            },
          )
        }
      }
    })
  })
}
