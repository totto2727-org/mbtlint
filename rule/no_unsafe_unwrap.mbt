///|
/// Report unchecked unwrapping of Option and Result values.
pub fn no_unsafe_unwrap() -> @core.Rule {
  builtin_rule("no-unsafe-unwrap", ctx => {
    safety_listener(ctx, expr => {
      let candidate = match expr {
        DotApply(method_name=label, args~, ..) if args.is_empty() => Some(label)
        _ =>
          match safety_callee(expr) {
            Some(Method(type_name={ name, .. }, method_name=label, ..)) => {
              let owner = safety_core_owner(name)
              if owner is Some("Result") ||
                (owner is Some("Option") && label.name == "unwrap") {
                Some(label)
              } else {
                None
              }
            }
            _ => None
          }
      }
      if candidate is Some({ name: "unwrap" | "unwrap_err", loc, }) {
        Some((loc, "Handle both cases instead of using an unchecked unwrap."))
      } else {
        None
      }
    })
  })
}
