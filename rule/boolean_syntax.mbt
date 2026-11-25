///|
fn simplification_ungroup(expr : @syntax.Expr) -> @syntax.Expr {
  for current = expr {
    match current {
      Group(expr~, ..) => continue expr
      other => break other
    }
  }
}

///|
fn simplification_bool(expr : @syntax.Expr) -> Bool? {
  match simplification_ungroup(expr) {
    Constant(c=Bool(value), ..) => Some(value)
    _ => None
  }
}

///|
fn simplification_bool_result(
  ctx : @core.Context,
  loc : @basic.Location,
  operand : @syntax.Expr,
  negate : Bool,
  message : String,
  allow_fix~ : Bool = true,
) -> Unit {
  let operand_loc = operand.loc()
  if allow_fix &&
    operand_loc.start.cnum >= loc.start.cnum &&
    operand_loc.end.cnum <= loc.end.cnum &&
    ctx.text(loc) is Some(original) &&
    !original.contains("//") &&
    !original.contains("/*") &&
    !original.contains("#|") &&
    !original.contains("$|") &&
    ctx.text(operand_loc) is Some(text) &&
    !text.is_empty() {
    // Preserve the original Bool expectation even in polymorphic contexts.
    let replacement = if negate { "(!(\{text}))" } else { "((\{text}) : Bool)" }
    (ctx.report_fix)(loc, message, replacement)
  } else {
    (ctx.report)(loc, message)
  }
}
