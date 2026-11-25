///|
fn report_pun(
  ctx : @core.Context,
  loc : @basic.Location,
  expected : String,
  replacement : String,
) -> Unit {
  let message = "Use the shorthand `\{replacement}`."
  if ctx.text(loc) is Some(text) {
    let tokens = StringBuilder()
    for c in text {
      if c != ' ' && c != '\t' && c != '\r' && c != '\n' {
        tokens.write_char(c)
      }
    }
    if tokens.to_string() == expected {
      (ctx.report_fix)(loc, message, replacement)
      return
    }
  }
  (ctx.report)(loc, message)
}
